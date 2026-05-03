use std::time::Duration;

const MAX_ATTEMPTS: u32 = 3;
const RETRY_DELAY: Duration = Duration::from_secs(1);

pub fn send(
    bot_token: &str,
    chat_id: &str,
    message: &str,
    timeout: Duration,
) -> Result<(), String> {
    let url = format!("https://api.telegram.org/bot{bot_token}/sendMessage");
    let agent = ureq::AgentBuilder::new().timeout(timeout).build();

    let mut last = String::new();
    for attempt in 0..MAX_ATTEMPTS {
        match agent
            .post(&url)
            .send_form(&[("chat_id", chat_id), ("text", message)])
        {
            Ok(_) => return Ok(()),
            Err(e) => {
                last = e.to_string();
                if attempt + 1 < MAX_ATTEMPTS {
                    std::thread::sleep(RETRY_DELAY);
                }
            }
        }
    }
    Err(format!("telegram send failed: {last}"))
}
