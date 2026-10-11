// Deterministic synthetic echo test. No microphone, speaker, network or files.
#include <array>
#include <cmath>
#include <cstdint>
#include <cstdio>
#include "modules/audio_processing/include/audio_processing.h"
#include "api/scoped_refptr.h"

int main() {
  rtc::scoped_refptr<webrtc::AudioProcessing> apm(webrtc::AudioProcessingBuilder().Create());
  webrtc::AudioProcessing::Config config;
  config.echo_canceller.enabled = true;
  config.noise_suppression.enabled = true;
  apm->ApplyConfig(config);
  std::array<int16_t, 160> render{}, capture{};
  std::array<int16_t, 80> output{};
  std::array<int16_t, 640> history{};
  size_t cursor = 0;
  uint32_t random = 18018;
  double before = 0, after = 0;
  float filtered = 0;
  const webrtc::StreamConfig pcm(16000, 1), wire(8000, 1);
  for (int frame = 0; frame < 1200; frame++) {
    for (size_t i = 0; i < render.size(); i++) {
      random = 1664525 * random + 1013904223;
      filtered = filtered * .7f + static_cast<int16_t>(random >> 16) * .06f;
      render[i] = static_cast<int16_t>(filtered);
      capture[i] = history[cursor] / 2;
      history[cursor] = render[i]; cursor = (cursor + 1) % history.size();
    }
    if (apm->ProcessReverseStream(render.data(), pcm, pcm, render.data())) return 2;
    apm->set_stream_delay_ms(40);
    if (apm->ProcessStream(capture.data(), pcm, wire, output.data())) return 3;
    if (frame > 900) {
      for (size_t i = 0; i < output.size(); i++) {
        before += static_cast<double>(capture[2*i]) * capture[2*i];
        after += static_cast<double>(output[i]) * output[i];
      }
    }
  }
  double reduction = 10 * std::log10(before / std::fmax(after, 1));
  std::printf("{\"synthetic_echo_reduction_db\":%.2f,\"frames\":1200,\"microphone_used\":false}\n", reduction);
  return reduction >= 6 ? 0 : 1;
}
