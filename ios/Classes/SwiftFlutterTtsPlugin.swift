import Flutter
import UIKit
import AVFoundation



public class SwiftFlutterTtsPlugin: NSObject, FlutterPlugin, AVSpeechSynthesizerDelegate {
  final var iosAudioCategoryKey = "iosAudioCategoryKey"
  final var iosAudioCategoryOptionsKey = "iosAudioCategoryOptionsKey"
  
  let synthesizer = AVSpeechSynthesizer()
  var language: String = AVSpeechSynthesisVoice.currentLanguageCode()
  var rate: Float = AVSpeechUtteranceDefaultSpeechRate
  var languages = Set<String>()
  var volume: Float = 1.0
  var pitch: Float = 1.0
  var voice: AVSpeechSynthesisVoice?
  
  var channel = FlutterMethodChannel()
  lazy var audioSession = AVAudioSession.sharedInstance()
  init(channel: FlutterMethodChannel) {
    super.init()
    self.channel = channel
    synthesizer.delegate = self
    setLanguages()
    
    // Allow audio playback when the Ring/Silent switch is set to silent
    do {
        try audioSession.setCategory(.playAndRecord, options: [.defaultToSpeaker])
    } catch {
      print(error)
    }
  }

  private func setLanguages() {
    for voice in AVSpeechSynthesisVoice.speechVoices(){
      self.languages.insert(voice.language)
    }
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_tts", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterTtsPlugin(channel: channel)
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "speak":
      let text: String = call.arguments as! String
      self.speak(text: text, result: result)
      break
    case "pause":
      self.pause(result: result)
      break
    case "setLanguage":
      let language: String = call.arguments as! String
      self.setLanguage(language: language, result: result)
      break
    case "setSpeechRate":
      let rate: Double = call.arguments as! Double
      self.setRate(rate: Float(rate))
      result(1)
      break
    case "setVolume":
      let volume: Double = call.arguments as! Double
      self.setVolume(volume: Float(volume), result: result)
      break
    case "setPitch":
      let pitch: Double = call.arguments as! Double
      self.setPitch(pitch: Float(pitch), result: result)
      break
    case "stop":
      self.stop()
      result(1)
      break
    case "getLanguages":
      self.getLanguages(result: result)
      break
    case "getSpeechRateValidRange":
      self.getSpeechRateValidRange(result: result)
      break
    case "isLanguageAvailable":
      let language: String = call.arguments as! String
      self.isLanguageAvailable(language: language, result: result)
      break
    case "getVoices":
      self.getVoices(result: result)
      break
    case "setVoice":
      let voiceName = call.arguments as! String
      self.setVoice(voiceName: voiceName, result: result)
      break
    case "setSharedInstance":
      let sharedInstance = call.arguments as! Bool
      self.setSharedInstance(sharedInstance: sharedInstance, result: result)
      break
    case "setIosAudioCategory":
      guard let args = call.arguments as? [String: Any] else {
        result("iOS could not recognize flutter arguments in method: (sendParams)")
        return
      }
      let audioCategory = args["iosAudioCategoryKey"] as? String
      let audioOptions = args[iosAudioCategoryOptionsKey] as? Array<String>
      self.setAudioCategory(audioCategory: audioCategory, audioOptions: audioOptions, result: result)
      break
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func speak(text: String, result: FlutterResult) {
    if (self.synthesizer.isPaused) {
      if (self.synthesizer.continueSpeaking()) {
        result(1)
      } else {
        result(0)
      }
    } else {
      let utterance = AVSpeechUtterance(string: text)
      if self.voice != nil {
        utterance.voice = self.voice!
      } else {
        utterance.voice = AVSpeechSynthesisVoice(language: self.language)
      }
      utterance.rate = self.rate
      utterance.volume = self.volume
      utterance.pitchMultiplier = self.pitch
      
      self.synthesizer.speak(utterance)
      result(1)
    }
  }

  private func pause(result: FlutterResult) {
      if (self.synthesizer.pauseSpeaking(at: AVSpeechBoundary.word)) {
        result(1)
      } else {
        result(0)
      }
  }

  private func setLanguage(language: String, result: FlutterResult) {
    if !(self.languages.contains(where: {$0.range(of: language, options: [.caseInsensitive, .anchored]) != nil})) {
      result(0)
    } else {
      self.language = language
      self.voice = nil
      result(1)
    }
  }

  private func setRate(rate: Float) {
    self.rate = rate
  }

  private func setVolume(volume: Float, result: FlutterResult) {
    if (volume >= 0.0 && volume <= 1.0) {
      self.volume = volume
      result(1)
    } else {
      result(0)
    }
  }

  private func setPitch(pitch: Float, result: FlutterResult) {
    if (volume >= 0.5 && volume <= 2.0) {
      self.pitch = pitch
      result(1)
    } else {
      result(0)
    }
  }
    
  private func setSharedInstance(sharedInstance: Bool, result: FlutterResult) {
      do {
          try AVAudioSession.sharedInstance().setActive(sharedInstance)
          result(1)
      } catch {
          result(0)
      }
  }
    private func setAudioCategory(audioCategory: String?, audioOptions: Array<String>?, result: FlutterResult){
        do{
            var category: AVAudioSession.Category = audioSession.category
            var options: AVAudioSession.CategoryOptions = []
            if(!(audioCategory?.isEmpty ?? true)){
                if(audioCategory == "iosAudioCategoryAmbientSolo"){
                    category = AVAudioSession.Category.soloAmbient
                }
                if(audioCategory == "iosAudioCategoryAmbient"){
                    category = AVAudioSession.Category.ambient
                }
                if(audioCategory == "iosAudioCategoryPlayback"){
                    category = AVAudioSession.Category.soloAmbient
                }
                if(audioCategory == "iosAudioCategoryPlaybackAndRecord"){
                    category = AVAudioSession.Category.soloAmbient
                }
            }
            if(!(audioOptions?.isEmpty ?? true)){
                if(audioOptions!.contains("iosAudioCategoryOptionsMixWithOthers")){
                    options.insert(AVAudioSession.CategoryOptions.mixWithOthers)
                }
                if(audioOptions!.contains("iosAudioCategoryOptionsDuckOthers")){
                    options.insert(AVAudioSession.CategoryOptions.duckOthers);
                }
                if #available(iOS 9.0, *) {
                    if(audioOptions!.contains("iosAudioCategoryOptionsInterruptSpokenAudioAndMixWithOthers")){
                        options.insert(AVAudioSession.CategoryOptions.interruptSpokenAudioAndMixWithOthers)
                    }
                }
                if(audioOptions!.contains("iosAudioCategoryOptionsAllowBluetooth")){
                    options.insert(AVAudioSession.CategoryOptions.allowBluetooth)
                }
                if #available(iOS 10.0, *) {
                    if(audioOptions!.contains("iosAudioCategoryOptionsAllowBluetoothA2DP")){
                        options.insert(AVAudioSession.CategoryOptions.allowBluetoothA2DP)
                    }
                    if(audioOptions!.contains("iosAudioCategoryOptionsAllowAirPlay")){
                        options.insert(AVAudioSession.CategoryOptions.allowAirPlay)
                    }
                }
                if(audioOptions!.contains("iosAudioCategoryOptionsDefaultToSpeaker")){
                    options.insert(AVAudioSession.CategoryOptions.defaultToSpeaker)
                }
            }
            try audioSession.setCategory(category, options: options)
        } catch {
             print(error)
        }
    
    }

  private func stop() {
    self.synthesizer.stopSpeaking(at: AVSpeechBoundary.immediate)
  }

  private func getLanguages(result: FlutterResult) {
    result(Array(self.languages))
  }

  private func getSpeechRateValidRange(result: FlutterResult) {
    let validSpeechRateRange: [String:String] = [
      "min": String(AVSpeechUtteranceMinimumSpeechRate),
      "normal": String(AVSpeechUtteranceDefaultSpeechRate),
      "max": String(AVSpeechUtteranceMaximumSpeechRate),
      "platform": "ios"
    ]
    result(validSpeechRateRange)
  }

  private func isLanguageAvailable(language: String, result: FlutterResult) {
    var isAvailable: Bool = false
    if (self.languages.contains(where: {$0.range(of: language, options: [.caseInsensitive, .anchored]) != nil})) {
      isAvailable = true
    }
    result(isAvailable);
  }

  private func getVoices(result: FlutterResult) {
    if #available(iOS 9.0, *) {
      let voices = NSMutableArray()
      for voice in AVSpeechSynthesisVoice.speechVoices() {
        voices.add(voice.name)
      }
      result(voices)
    } else {
      // Since voice selection is not supported below iOS 9, make voice getter and setter
      // have the same bahavior as language selection.
      getLanguages(result: result)
    }
  }

  private func setVoice(voiceName: String, result: FlutterResult) {
    if #available(iOS 9.0, *) {
      if let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.name == voiceName }) {
        self.voice = voice
        self.language = voice.language
        result(1)
        return
      }
      result(0)
    } else {
      setLanguage(language: voiceName, result: result)
    }
  }

  public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
    do {
        // try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
    } catch {
      print(error)
    }
    self.channel.invokeMethod("speak.onComplete", arguments: nil)
  }

  public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
    self.channel.invokeMethod("speak.onStart", arguments: nil)
  }

  public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
    let nsWord = utterance.speechString as NSString
    let data: [String:String] = [
      "text": utterance.speechString,
      "start": String(characterRange.location),
      "end": String(characterRange.location + characterRange.length),
      "word": nsWord.substring(with: characterRange)
    ]
    self.channel.invokeMethod("speak.onProgress", arguments: data)
  }

}
