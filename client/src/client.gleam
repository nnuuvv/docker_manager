import container_data.{type ContainerData}
import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp

pub fn main() -> Nil {
  let flags = get_initial_state()

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", flags)

  Nil
}

pub type Model {
  Model(container_data: List(ContainerData))
}

fn get_initial_state() -> List(ContainerData) {
  []
}

fn init(_) -> #(Model, Effect(Msg)) {
  let model = Model([])

  #(model, effect.none())
}

// UPDATE -------------------------------------------------------------------

pub opaque type Msg {
  UserClickedUpdateContainerData
  ServerUpdatedContainerData(data: Result(List(ContainerData), rsvp.Error))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  model |> echo
  msg |> echo
  case msg {
    UserClickedUpdateContainerData -> {
      #(model, update_container_data())
    }
    ServerUpdatedContainerData(data) -> {
      let value = case data {
        Error(error) -> {
          error |> echo

          model
        }
        Ok(container_data) -> Model(..model, container_data:)
      }

      #(value, effect.none())
    }
  }
}

fn update_container_data() -> Effect(Msg) {
  let url = "/api/container_data/"

  let decoder = decode.list(container_data.container_data_decoder())
  let handler = rsvp.expect_json(decoder, ServerUpdatedContainerData)

  rsvp.get(url, handler)
}

// VIEW ---------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  let styles = [#("display", "flex"), #("justify-content", "space-between")]
  html.div([attribute.styles(styles)], [
    html.button([event.on_click(UserClickedUpdateContainerData)], [
      html.text("Update"),
    ]),
    html.div(
      [attribute.styles(styles)],
      list.map(model.container_data, fn(item) { view_container(item) }),
    ),
  ])
}

fn view_container(data: ContainerData) {
  html.div([], [
    html.text(
      "Container: " <> list.fold(data.names, "", fn(a, b) { a <> " " <> b }),
    ),
  ])
}
