#include <jni.h>
#include <array>
#include <mutex>
#include "modules/audio_processing/include/audio_processing.h"
#include "api/scoped_refptr.h"

// All processing is mono, 10 ms at 16 kHz. No audio dumps or file I/O.
struct Processor {
  rtc::scoped_refptr<webrtc::AudioProcessing> apm;
  std::mutex mutex;
  Processor() : apm(webrtc::AudioProcessingBuilder().Create()) {
    webrtc::AudioProcessing::Config config;
    config.echo_canceller.enabled = true;
    config.echo_canceller.mobile_mode = false;
    config.noise_suppression.enabled = true;
    config.high_pass_filter.enabled = true;
    apm->ApplyConfig(config);
  }
};

extern "C" JNIEXPORT jlong JNICALL
Java_nl_mennovanhout_nspanel_1app_intercom_AudioProcessor_create(JNIEnv*, jobject) {
  return reinterpret_cast<jlong>(new Processor());
}

extern "C" JNIEXPORT jint JNICALL
Java_nl_mennovanhout_nspanel_1app_intercom_AudioProcessor_process(
    JNIEnv* env, jobject, jlong handle, jshortArray samples, jboolean reverse, jint delay) {
  if (!handle || env->GetArrayLength(samples) != 160) return -1;
  auto* p = reinterpret_cast<Processor*>(handle);
  std::lock_guard<std::mutex> guard(p->mutex);
  std::array<int16_t, 160> frame;
  env->GetShortArrayRegion(samples, 0, 160, frame.data());
  const webrtc::StreamConfig format(16000, 1);
  int result;
  if (reverse) {
    result = p->apm->ProcessReverseStream(frame.data(), format, format, frame.data());
  } else {
    p->apm->set_stream_delay_ms(delay);
    const webrtc::StreamConfig wire_format(8000, 1);
    std::array<int16_t, 80> output;
    result = p->apm->ProcessStream(frame.data(), format, wire_format, output.data());
    if (!result) env->SetShortArrayRegion(samples, 0, 80, output.data());
  }
  return result;
}

extern "C" JNIEXPORT void JNICALL
Java_nl_mennovanhout_nspanel_1app_intercom_AudioProcessor_destroy(JNIEnv*, jobject, jlong handle) {
  delete reinterpret_cast<Processor*>(handle);
}
