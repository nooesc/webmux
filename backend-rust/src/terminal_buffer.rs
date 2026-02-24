use simdutf8;

/// Zero-copy UTF-8 streaming decoder for terminal output chunks
pub struct Utf8StreamDecoder {
    incomplete: Vec<u8>,
}

impl Utf8StreamDecoder {
    pub fn new() -> Self {
        Self {
            incomplete: Vec::with_capacity(4),
        }
    }

    pub fn decode_chunk(&mut self, input: &[u8]) -> (String, usize) {
        let mut result = String::with_capacity(input.len());
        let mut processed = 0;

        // Handle incomplete bytes from previous chunk
        if !self.incomplete.is_empty() {
            let combined_len = self.incomplete.len() + input.len().min(4);
            let mut combined = Vec::with_capacity(combined_len);
            combined.extend_from_slice(&self.incomplete);
            combined.extend_from_slice(&input[..input.len().min(4)]);

            match simdutf8::basic::from_utf8(&combined) {
                Ok(s) => {
                    result.push_str(s);
                    processed = combined.len() - self.incomplete.len();
                    self.incomplete.clear();
                }
                Err(_) => {
                    match std::str::from_utf8(&combined) {
                        Ok(s) => {
                            result.push_str(s);
                            processed = combined.len() - self.incomplete.len();
                            self.incomplete.clear();
                        }
                        Err(e) => {
                            let valid_up_to = e.valid_up_to();
                            if valid_up_to > 0 {
                                // SAFETY: We validated the prefix as UTF-8 above.
                                result.push_str(unsafe {
                                    std::str::from_utf8_unchecked(&combined[..valid_up_to])
                                });
                                processed = valid_up_to.saturating_sub(self.incomplete.len());
                                self.incomplete.clear();
                            }
                        }
                    }
                }
            }
        }

        // Process main input
        let remaining = &input[processed..];
        match simdutf8::basic::from_utf8(remaining) {
            Ok(s) => {
                result.push_str(s);
                processed = input.len();
            }
            Err(_) => {
                match std::str::from_utf8(remaining) {
                    Ok(s) => {
                        result.push_str(s);
                        processed = input.len();
                    }
                    Err(e) => {
                        let valid_up_to = e.valid_up_to();
                        if valid_up_to > 0 {
                            // SAFETY: We validated the valid prefix above.
                            result.push_str(unsafe {
                                std::str::from_utf8_unchecked(&remaining[..valid_up_to])
                            });
                        }

                        // Save incomplete bytes for next chunk
                        let incomplete_start = processed + valid_up_to;
                        if incomplete_start < input.len() {
                            self.incomplete.clear();
                            self.incomplete.extend_from_slice(&input[incomplete_start..]);
                        }
                        processed = input.len();
                    }
                }
            }
        }

        (result, processed)
    }
}
