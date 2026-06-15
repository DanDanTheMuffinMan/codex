use std::collections::HashMap;
use std::sync::Mutex;
use std::sync::MutexGuard;
use std::sync::atomic::AtomicI64;
use std::sync::atomic::Ordering;

use codex_app_server_protocol::JSONRPCErrorError;
use codex_app_server_protocol::RequestId;
use codex_app_server_protocol::Result;
use codex_app_server_protocol::ServerNotification;
use codex_app_server_protocol::ServerRequest;
use codex_app_server_protocol::ServerRequestPayload;
use serde::Serialize;
use tokio::sync::mpsc;
use tokio::sync::oneshot;
use tracing::warn;

use crate::error_code::INTERNAL_ERROR_CODE;

/// Sends messages to the client and manages request callbacks.
pub(crate) struct OutgoingMessageSender {
    next_request_id: AtomicI64,
    sender: mpsc::Sender<OutgoingMessage>,
    request_id_to_callback: Mutex<HashMap<RequestId, oneshot::Sender<Result>>>,
}

impl OutgoingMessageSender {
    pub(crate) fn new(sender: mpsc::Sender<OutgoingMessage>) -> Self {
        Self {
            next_request_id: AtomicI64::new(0),
            sender,
            request_id_to_callback: Mutex::new(HashMap::new()),
        }
    }

    pub(crate) async fn send_request(
        &self,
        request: ServerRequestPayload,
    ) -> oneshot::Receiver<Result> {
        let id = RequestId::Integer(self.next_request_id.fetch_add(1, Ordering::Relaxed));
        let outgoing_message_id = id.clone();
        let (tx_approve, rx_approve) = oneshot::channel();
        {
            let mut request_id_to_callback = lock_callbacks(&self.request_id_to_callback);
            request_id_to_callback.insert(id.clone(), tx_approve);
        }
        let mut callback_cleanup =
            PendingRequestCallbackCleanup::new(id.clone(), &self.request_id_to_callback);

        let outgoing_message =
            OutgoingMessage::Request(request.request_with_id(outgoing_message_id));
        if self.sender.send(outgoing_message).await.is_ok() {
            callback_cleanup.disarm();
        }
        rx_approve
    }

    pub(crate) async fn notify_client_response(&self, id: RequestId, result: Result) {
        let entry = {
            let mut request_id_to_callback = lock_callbacks(&self.request_id_to_callback);
            request_id_to_callback.remove_entry(&id)
        };

        match entry {
            Some((id, sender)) => {
                if let Err(err) = sender.send(result) {
                    warn!("could not notify callback for {id:?} due to: {err:?}");
                }
            }
            None => {
                warn!("could not find callback for {id:?}");
            }
        }
    }

    pub(crate) async fn send_response<T: Serialize>(&self, id: RequestId, response: T) {
        match serde_json::to_value(response) {
            Ok(result) => {
                let outgoing_message = OutgoingMessage::Response(OutgoingResponse { id, result });
                let _ = self.sender.send(outgoing_message).await;
            }
            Err(err) => {
                self.send_error(
                    id,
                    JSONRPCErrorError {
                        code: INTERNAL_ERROR_CODE,
                        message: format!("failed to serialize response: {err}"),
                        data: None,
                    },
                )
                .await;
            }
        }
    }

    pub(crate) async fn send_server_notification(&self, notification: ServerNotification) {
        let _ = self
            .sender
            .send(OutgoingMessage::AppServerNotification(notification))
            .await;
    }

    /// All notifications should be migrated to [`ServerNotification`] and
    /// [`OutgoingMessage::Notification`] should be removed.
    pub(crate) async fn send_notification(&self, notification: OutgoingNotification) {
        let outgoing_message = OutgoingMessage::Notification(notification);
        let _ = self.sender.send(outgoing_message).await;
    }

    pub(crate) async fn send_error(&self, id: RequestId, error: JSONRPCErrorError) {
        let outgoing_message = OutgoingMessage::Error(OutgoingError { id, error });
        let _ = self.sender.send(outgoing_message).await;
    }
}

fn lock_callbacks(
    request_id_to_callback: &Mutex<HashMap<RequestId, oneshot::Sender<Result>>>,
) -> MutexGuard<'_, HashMap<RequestId, oneshot::Sender<Result>>> {
    match request_id_to_callback.lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

struct PendingRequestCallbackCleanup<'a> {
    id: RequestId,
    request_id_to_callback: &'a Mutex<HashMap<RequestId, oneshot::Sender<Result>>>,
    armed: bool,
}

impl<'a> PendingRequestCallbackCleanup<'a> {
    fn new(
        id: RequestId,
        request_id_to_callback: &'a Mutex<HashMap<RequestId, oneshot::Sender<Result>>>,
    ) -> Self {
        Self {
            id,
            request_id_to_callback,
            armed: true,
        }
    }

    fn disarm(&mut self) {
        self.armed = false;
    }
}

impl Drop for PendingRequestCallbackCleanup<'_> {
    fn drop(&mut self) {
        if self.armed {
            let mut request_id_to_callback = lock_callbacks(self.request_id_to_callback);
            request_id_to_callback.remove(&self.id);
        }
    }
}

/// Outgoing message from the server to the client.
#[derive(Debug, Clone, Serialize)]
#[serde(untagged)]
pub(crate) enum OutgoingMessage {
    Request(ServerRequest),
    Notification(OutgoingNotification),
    /// AppServerNotification is specific to the case where this is run as an
    /// "app server" as opposed to an MCP server.
    AppServerNotification(ServerNotification),
    Response(OutgoingResponse),
    Error(OutgoingError),
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub(crate) struct OutgoingNotification {
    pub method: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub params: Option<serde_json::Value>,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub(crate) struct OutgoingResponse {
    pub id: RequestId,
    pub result: Result,
}

#[derive(Debug, Clone, PartialEq, Serialize)]
pub(crate) struct OutgoingError {
    pub error: JSONRPCErrorError,
    pub id: RequestId,
}

#[cfg(test)]
mod tests {
    use codex_app_server_protocol::AccountLoginCompletedNotification;
    use codex_app_server_protocol::AccountRateLimitsUpdatedNotification;
    use codex_app_server_protocol::AccountUpdatedNotification;
    use codex_app_server_protocol::AuthMode;
    use codex_app_server_protocol::ExecCommandApprovalParams;
    use codex_app_server_protocol::LoginChatGptCompleteNotification;
    use codex_app_server_protocol::RateLimitSnapshot;
    use codex_app_server_protocol::RateLimitWindow;
    use codex_protocol::ConversationId;
    use codex_protocol::parse_command::ParsedCommand;
    use pretty_assertions::assert_eq;
    use serde_json::json;
    use tokio::time::Duration;
    use uuid::Uuid;

    use super::*;

    #[test]
    fn verify_server_notification_serialization() {
        let notification =
            ServerNotification::LoginChatGptComplete(LoginChatGptCompleteNotification {
                login_id: Uuid::nil(),
                success: true,
                error: None,
            });

        let jsonrpc_notification = OutgoingMessage::AppServerNotification(notification);
        assert_eq!(
            json!({
                "method": "loginChatGptComplete",
                "params": {
                    "loginId": Uuid::nil(),
                    "success": true,
                    "error": null,
                },
            }),
            serde_json::to_value(jsonrpc_notification)
                .expect("ensure the strum macros serialize the method field correctly"),
            "ensure the strum macros serialize the method field correctly"
        );
    }

    #[test]
    fn verify_account_login_completed_notification_serialization() {
        let notification =
            ServerNotification::AccountLoginCompleted(AccountLoginCompletedNotification {
                login_id: Some(Uuid::nil().to_string()),
                success: true,
                error: None,
            });

        let jsonrpc_notification = OutgoingMessage::AppServerNotification(notification);
        assert_eq!(
            json!({
                "method": "account/login/completed",
                "params": {
                    "loginId": Uuid::nil().to_string(),
                    "success": true,
                    "error": null,
                },
            }),
            serde_json::to_value(jsonrpc_notification)
                .expect("ensure the notification serializes correctly"),
            "ensure the notification serializes correctly"
        );
    }

    #[test]
    fn verify_account_rate_limits_notification_serialization() {
        let notification =
            ServerNotification::AccountRateLimitsUpdated(AccountRateLimitsUpdatedNotification {
                rate_limits: RateLimitSnapshot {
                    primary: Some(RateLimitWindow {
                        used_percent: 25,
                        window_duration_mins: Some(15),
                        resets_at: Some(123),
                    }),
                    secondary: None,
                },
            });

        let jsonrpc_notification = OutgoingMessage::AppServerNotification(notification);
        assert_eq!(
            json!({
                "method": "account/rateLimits/updated",
                "params": {
                    "rateLimits": {
                        "primary": {
                            "usedPercent": 25,
                            "windowDurationMins": 15,
                            "resetsAt": 123
                        },
                        "secondary": null
                    }
                },
            }),
            serde_json::to_value(jsonrpc_notification)
                .expect("ensure the notification serializes correctly"),
            "ensure the notification serializes correctly"
        );
    }

    #[test]
    fn verify_account_updated_notification_serialization() {
        let notification = ServerNotification::AccountUpdated(AccountUpdatedNotification {
            auth_mode: Some(AuthMode::ApiKey),
        });

        let jsonrpc_notification = OutgoingMessage::AppServerNotification(notification);
        assert_eq!(
            json!({
                "method": "account/updated",
                "params": {
                    "authMode": "apikey"
                },
            }),
            serde_json::to_value(jsonrpc_notification)
                .expect("ensure the notification serializes correctly"),
            "ensure the notification serializes correctly"
        );
    }

    #[tokio::test]
    async fn cancelled_request_send_removes_callback() {
        let (sender, _receiver) = mpsc::channel(1);
        sender
            .send(OutgoingMessage::Notification(OutgoingNotification {
                method: "queued".to_string(),
                params: None,
            }))
            .await
            .expect("queue should accept the first message");
        let outgoing = OutgoingMessageSender::new(sender);

        let request = outgoing.send_request(ServerRequestPayload::ExecCommandApproval(
            ExecCommandApprovalParams {
                conversation_id: ConversationId::from_string(
                    "67e55044-10b1-426f-9247-bb680e5fe0c8",
                )
                .expect("valid conversation id"),
                call_id: "call-42".to_string(),
                command: vec!["echo".to_string(), "hello".to_string()],
                cwd: "/tmp".into(),
                reason: Some("because tests".to_string()),
                risk: None,
                parsed_cmd: vec![ParsedCommand::Unknown {
                    cmd: "echo hello".to_string(),
                }],
            },
        ));
        let timed_out = tokio::time::timeout(Duration::from_millis(10), request)
            .await
            .is_err();

        assert!(timed_out);
        assert_eq!(
            outgoing
                .request_id_to_callback
                .lock()
                .unwrap_or_else(std::sync::PoisonError::into_inner)
                .len(),
            0
        );
    }
}
