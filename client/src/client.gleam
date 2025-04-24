import gleam/dynamic
import gleam/dynamic/decode
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rsvp
import shared/container.{type Container}
import shared/container_data.{type ContainerData}
import shared/node.{type Node}
import shared/virtual_machine.{type VirtualMachine}

pub fn main() -> Nil {
  let flags = get_initial_state()

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", flags)

  Nil
}

pub type Model {
  Model(node_data: List(Node))
}

fn get_initial_state() -> List(Node) {
  []
}

fn init(_) -> #(Model, Effect(Msg)) {
  let model = Model([])

  #(model, effect.none())
}

// UPDATE -------------------------------------------------------------------

pub opaque type Msg {
  UserClickedUpdateContainerData
  ServerUpdatedNodeData(data: Result(Node, rsvp.Error))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  model |> echo
  msg |> echo

  case msg {
    UserClickedUpdateContainerData -> {
      #(model, update_container_data())
    }
    ServerUpdatedNodeData(data) -> {
      let value = case data {
        Error(error) -> {
          error |> echo

          model
        }
        Ok(node) -> {
          model.node_data
          |> list.filter(fn(cur) { cur.name != node.name })
          |> list.prepend(node)
          |> Model
        }
      }

      #(value, effect.none())
    }
  }
}

fn update_container_data() -> Effect(Msg) {
  let url = "/api/node_data/"

  let handler = rsvp.expect_json(node.node_decoder(), ServerUpdatedNodeData)

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
      list.map(model.node_data, fn(node) { view_node(node) }),
    ),
  ])
}

fn view_node(node: Node) {
  html.div(
    [],
    node.virtual_machines
      |> list.map(fn(vm) { view_virtual_machine(vm) }),
  )
}

fn view_virtual_machine(vm: VirtualMachine) {
  let container_elements = case vm.containers {
    option.None -> html.div([], [])
    option.Some(containers) ->
      html.div(
        [],
        containers |> list.map(fn(container) { view_container(container) }),
      )
  }

  html.div([], [container_elements])
}

fn view_container(data: Container) -> Element(Msg) {
  html.div([], [
    html.text(
      "Container: "
      <> list.fold(data.data.names, "", fn(a, b) { a <> " " <> b }),
    ),
  ])
}
