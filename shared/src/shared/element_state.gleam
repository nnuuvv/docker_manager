import gleam/json
import gleam/dynamic/decode

pub type ElementState {
  Collapsed
  Expanded
}

pub fn encode_element_state(element_state: ElementState) -> json.Json {
  case element_state {
    Collapsed -> json.string("collapsed")
    Expanded -> json.string("expanded")
  }
}

pub fn element_state_decoder() -> decode.Decoder(ElementState) {
  use variant <- decode.then(decode.string)
  case variant {
    "collapsed" -> decode.success(Collapsed)
    "expanded" -> decode.success(Expanded)
    _ -> decode.failure(Collapsed, "ElementState")
  }
}
