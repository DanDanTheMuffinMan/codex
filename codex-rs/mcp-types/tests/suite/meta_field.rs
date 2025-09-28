use mcp_types::AudioContent;
use mcp_types::TextContent;
use serde_json::json;

#[test]
fn test_meta_field_serialization() {
    // Test serialization with _meta field present
    let audio_with_meta = AudioContent {
        _meta: Some(json!({
            "custom_property": "test_value",
            "number": 42
        })),
        annotations: None,
        data: "base64data".to_string(),
        mime_type: "audio/wav".to_string(),
        r#type: "audio".to_string(),
    };

    let serialized = serde_json::to_value(&audio_with_meta).expect("should serialize");
    assert_eq!(serialized["_meta"]["custom_property"], json!("test_value"));
    assert_eq!(serialized["_meta"]["number"], json!(42));

    // Test serialization without _meta field (should be omitted)
    let audio_without_meta = AudioContent {
        _meta: None,
        annotations: None,
        data: "base64data".to_string(),
        mime_type: "audio/wav".to_string(),
        r#type: "audio".to_string(),
    };

    let serialized = serde_json::to_value(&audio_without_meta).expect("should serialize");
    assert!(!serialized.as_object().unwrap().contains_key("_meta"));
}

#[test]
fn test_meta_field_deserialization() {
    // Test deserialization with _meta field present
    let json_with_meta = json!({
        "_meta": {
            "custom_property": "test_value",
            "number": 42
        },
        "data": "base64data",
        "mimeType": "audio/wav",
        "type": "audio"
    });

    let audio: AudioContent = serde_json::from_value(json_with_meta).expect("should deserialize");
    assert!(audio._meta.is_some());
    let meta = audio._meta.unwrap();
    assert_eq!(meta["custom_property"], json!("test_value"));
    assert_eq!(meta["number"], json!(42));

    // Test deserialization without _meta field (should default to None)
    let json_without_meta = json!({
        "data": "base64data",
        "mimeType": "audio/wav",
        "type": "audio"
    });

    let audio: AudioContent =
        serde_json::from_value(json_without_meta).expect("should deserialize");
    assert!(audio._meta.is_none());
}

#[test]
fn test_meta_field_multiple_structures() {
    // Test that _meta works across different structures that have it
    let text_with_meta = TextContent {
        _meta: Some(json!({
            "priority": "high",
            "source": "user_input"
        })),
        annotations: None,
        text: "Hello world".to_string(),
        r#type: "text".to_string(),
    };

    let serialized = serde_json::to_value(&text_with_meta).expect("should serialize");
    assert_eq!(serialized["_meta"]["priority"], json!("high"));
    assert_eq!(serialized["_meta"]["source"], json!("user_input"));
    assert_eq!(serialized["text"], json!("Hello world"));
    
    // Verify we can deserialize it back
    let deserialized: TextContent = serde_json::from_value(serialized).expect("should deserialize");
    assert!(deserialized._meta.is_some());
    assert_eq!(deserialized.text, "Hello world");
}
