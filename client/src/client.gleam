import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http/response
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/option
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/timestamp
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/svg
import lustre/event
import rsvp
import shared/container.{type Container}
import shared/container_data.{type ContainerData}
import shared/element_state
import shared/node.{type Node}
import shared/virtual_machine.{type VirtualMachine}

const green = "#2f9e44"

const red = "#fa5252"

const orange = "#fab005"

const blue = "#4dabf7"

const white = "#d8d4d4"

const background = "#181414"

pub fn main() -> Nil {
  let flags = get_initial_state()

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", flags)

  Nil
}

pub type Model {
  Model(node_data: List(Node), selected: Selected)
}

pub type Selected {
  None
  SelectedNode(node: Node)
  SelectedNodeContainer(container: Container, compose_file: String)
  SelectedVirtualMachine(virtual_machine: VirtualMachine)
  SelectedVirtualMachineContainer(container: Container, compose_file: String)
}

fn get_initial_state() -> List(Node) {
  []
}

fn init(_) -> #(Model, Effect(Msg)) {
  let model = Model([], None)

  #(model, effect.none())
}

// UPDATE -------------------------------------------------------------------

pub opaque type Msg {
  UserClickedUpdateNodeData
  ServerUpdatedNodeData(data: Result(Node, rsvp.Error))
  UserSelectedItem(selected: Selected)
  ServerReturnedComposeFile(file: Result(String, rsvp.Error))
  UserUpdatedComposeFile(file: String)
  UserClickedSaveComposeFile
  ServerSavedComposeFile(
    save_result: Result(response.Response(String), rsvp.Error),
  )
  UserClickedStartContainer
  UserClickedStopContainer
  UserClickedRestartContainer
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  model |> echo
  msg |> echo

  case msg {
    UserClickedUpdateNodeData -> {
      #(model, update_node_data())
    }
    ServerUpdatedNodeData(data) -> {
      let value = case data {
        Error(_error) -> {
          model
        }
        Ok(node) -> {
          Model(
            ..model,
            node_data: model.node_data
              //|> list.filter(fn(cur) { cur.name != node.name })
              |> list.prepend(node),
          )
        }
      }

      #(value, effect.none())
    }
    UserSelectedItem(selected) -> {
      // make sure to set the file to empty when we change the selected item
      let model = Model(..model, selected: update_compose_file(selected, ""))

      let effect = case selected {
        SelectedNodeContainer(_, _) | SelectedVirtualMachineContainer(_, _) ->
          handle_get_compose_file(selected)
        _ -> effect.none()
      }

      #(model, effect)
    }
    ServerReturnedComposeFile(file) -> {
      case file {
        Error(_error) -> {
          #(model, effect.none())
        }
        Ok(file) -> {
          let selected = update_compose_file(model.selected, file)

          #(Model(..model, selected: selected), effect.none())
        }
      }
    }
    UserUpdatedComposeFile(file) -> {
      let selected = update_compose_file(model.selected, file)
      #(Model(..model, selected: selected), effect.none())
    }
    UserClickedSaveComposeFile -> {
      let effect = save_compose_file(model.selected)
      #(model, effect)
    }
    ServerSavedComposeFile(_save_result) -> {
      // add some sort of info for the end user that it either saved or had an issue saving
      #(model, effect.none())
    }
    UserClickedStartContainer -> {
      todo
    }
    UserClickedStopContainer -> {
      todo
    }
    UserClickedRestartContainer -> {
      todo
    }
  }
}

// COMPOSE HANDLING --------------------------------------------------------

fn save_compose_file(selected: Selected) -> Effect(Msg) {
  case selected {
    SelectedNodeContainer(container, file)
    | SelectedVirtualMachineContainer(container, file) -> {
      let container_name = get_container_name(container.data.names)
      case container_name {
        Error(_) -> effect.none()
        Ok(container_name) -> {
          let url = "/compose/" <> container_name

          let handler = rsvp.expect_ok_response(ServerSavedComposeFile)

          rsvp.post(url, json.string(file), handler)
        }
      }
    }
    _ -> effect.none()
  }
}

fn update_compose_file(selected: Selected, file) -> Selected {
  case selected {
    SelectedNodeContainer(container, _) ->
      SelectedNodeContainer(container, file)
    SelectedVirtualMachineContainer(container, _) ->
      SelectedVirtualMachineContainer(container, file)
    _ -> selected
  }
}

fn handle_get_compose_file(selected: Selected) -> Effect(Msg) {
  case selected {
    SelectedNodeContainer(container, _)
    | SelectedVirtualMachineContainer(container, _) -> {
      let container_name = get_container_name(container.data.names)
      case container_name {
        Error(_) -> effect.none()
        Ok(container_name) -> {
          let url = "/compose/" <> container_name

          let handler = rsvp.expect_text(ServerReturnedComposeFile)

          rsvp.get(url, handler)
        }
      }
    }
    _ -> effect.none()
  }
}

fn get_container_name(container_names: List(String)) {
  case list.first(container_names) {
    Error(error) -> Error(error)
    Ok(container_name) -> {
      let container_name = case string.starts_with(container_name, "/") {
        False -> container_name
        True -> string.drop_start(container_name, 1)
      }
      Ok(container_name)
    }
  }
}

// NODE DATA ---------------------------------------------------------------

fn update_node_data() -> Effect(Msg) {
  let url = "/api/node_data/"

  let handler = rsvp.expect_json(node.node_decoder(), ServerUpdatedNodeData)

  rsvp.get(url, handler)
}

// VIEW ---------------------------------------------------------------------

pub fn view(model: Model) -> Element(Msg) {
  let styles = [#("display", "flex"), #("justify-content", "space-between")]
  html.div([], [
    // temporary update button
    html.button([event.on_click(UserClickedUpdateNodeData)], [
      html.text("Update"),
    ]),
    html.div(
      [
        attribute.styles(styles),
        attribute.class("has-border"),
        attribute.id("main-window-border"),
      ],
      [
        // Picker
        html.div(
          [
            attribute.styles([
              #("flex-direction", "column"),
              #("display", "flex"),
              #("padding", "10px"),
            ]),
            attribute.styles([#("width", "35%"), #("height", "100vh")]),
            attribute.class("has-border"),
            attribute.id("node-list"),
          ],
          list.map(model.node_data, fn(node) { view_node(node, styles) }),
        ),
        // detail view
        html.div(
          [
            attribute.styles(styles),
            attribute.styles([
              #("width", "65%"),
              #("height", "100vh"),
              #("padding", "10px"),
            ]),
            attribute.class("has-border"),
            attribute.id("detail-content"),
          ],
          [view_selected_details(model.selected)],
        ),
      ],
    ),
  ])
}

// MAIN CONTENT ----------------------------------------------------------------------------------

fn view_selected_details(selected: Selected) -> Element(Msg) {
  case selected {
    None -> html.text("No item has been selected.")
    SelectedNode(node) -> view_node_details(node)
    SelectedNodeContainer(container, compose_file)
    | SelectedVirtualMachineContainer(container, compose_file) ->
      view_container_details(container, compose_file)
    SelectedVirtualMachine(vm) -> view_virtual_machine_details(vm)
  }
}

fn view_node_details(node: Node) -> Element(Msg) {
  html.div([], [
    html.text("imagine some detailed view of the " <> node.name <> " here."),
  ])
}

fn view_virtual_machine_details(vm: VirtualMachine) -> Element(Msg) {
  html.div([], [
    html.text("imagine some detailed view of the " <> vm.name <> " here."),
  ])
}

fn view_container_details(
  container: Container,
  compose_file: String,
) -> Element(Msg) {
  let square_button = [#("aspect-ratio", "1 / 1")]

  html.div([attribute.styles([#("width", "100%")])], [
    html.p(
      [attribute.styles([#("display", "flex"), #("flex-direction", "row")])],
      [
        html.text(
          get_container_name(container.data.names)
          |> result.unwrap("Name not found"),
        ),
        html.div(
          [
            attribute.id("button_panel"),
            attribute.styles([
              #("display", "flex"),
              #("justify_content", "space-between"),
            ]),
          ],
          [
            html.button(
              [
                attribute.id("start_button"),
                attribute.styles([#("background-color", green), ..square_button]),
                event.on_click(UserClickedStartContainer),
              ],
              [],
            ),
            html.button(
              [
                attribute.id("stop_button"),
                attribute.styles([#("background-color", red), ..square_button]),
                event.on_click(UserClickedStopContainer),
              ],
              [],
            ),
            html.button(
              [
                attribute.id("restart_button"),
                attribute.styles([
                  #("background-color", orange),
                  ..square_button
                ]),
                event.on_click(UserClickedRestartContainer),
              ],
              [],
            ),
            html.button(
              [
                attribute.id("update_apply_button"),
                attribute.styles([#("background-color", blue), ..square_button]),
                event.on_click(UserClickedSaveComposeFile),
              ],
              [],
            ),
          ],
        ),
      ],
    ),
    html.div([attribute.styles([#("width", "100%"), #("display", "flex")])], [
      html.textarea(
        [
          attribute.class("has-border"),
          attribute.styles([
            #("height", "50vh"),
            #("color", white),
            #("background-color", background),
            #("display", "flex"),
            #("flex-direction", "row"),
            #("flex", "auto"),
          ]),
          event.on_change(UserUpdatedComposeFile),
        ],
        compose_file,
      ),
    ]),
    html.p([], [
      html.text("Ports:"),
      html.ul(
        [],
        container.data.ports
          |> list.map(fn(port) {
            html.li([], [
              html.text(
                int.to_string(option.unwrap(port.public_port, 0))
                <> ":"
                <> int.to_string(option.unwrap(port.private_port, 0))
                <> "/"
                <> option.unwrap(port.port_type, ""),
              ),
            ])
          }),
      ),
    ]),
    html.p([], [
      html.text("Created: " <> unix_seconds_to_string(container.data.created)),
    ]),
  ])
}

fn unix_seconds_to_string(seconds: Int) -> String {
  let time: #(calendar.Date, calendar.TimeOfDay) =
    timestamp.from_unix_seconds(seconds)
    |> timestamp.to_calendar(calendar.local_offset())

  [
    int.to_string({ time.0 }.day),
    int.to_string(calendar.month_to_int({ time.0 }.month)),
    int.to_string({ time.0 }.year),
  ]
  |> string.join(".")
  <> " "
  <> string.join(
    [int.to_string({ time.1 }.hours), int.to_string({ time.1 }.minutes)],
    ":",
  )
}

// LEFT LIST VIEW -----------------------------------------------------------------------------

fn view_node(node: Node, styles: List(#(String, String))) {
  html.div([attribute.styles([#("width", "100%")]), attribute.id("node")], [
    html.div(
      [
        event.on_click(UserSelectedItem(SelectedNode(node))),
        attribute.id("node-details"),
      ],
      [html.text(node.name)],
    ),
    html.div([attribute.id("node-containers")], case node.containers {
      option.None -> []
      option.Some(vms) ->
        vms
        |> list.map(fn(container) {
          view_container(container, SelectedNodeContainer)
        })
    }),
    html.div([attribute.id("node-vms")], case node.virtual_machines {
      option.None -> [html.text("no vms found")]
      option.Some(vms) ->
        vms |> list.map(fn(vm) { view_virtual_machine(vm, styles) })
    }),
  ])
}

fn view_virtual_machine(vm: VirtualMachine, styles: List(#(String, String))) {
  let container_elements = case vm.containers, vm.element_state {
    option.None, element_state.Expanded -> html.text("no containers found")
    option.None, _ -> html.div([], [])
    option.Some(containers), _ ->
      html.div(
        [attribute.id("vm-containers")],
        containers
          |> list.map(fn(container) {
            view_container(container, SelectedVirtualMachineContainer)
          }),
      )
  }

  html.div(
    [
      event.on_click(UserSelectedItem(SelectedVirtualMachine(vm))),
      attribute.class("clickable"),
      attribute.id("vm"),
    ],
    [html.text(vm.name), container_elements],
  )
}

fn view_container_sublist(containers: List(Container)) {
  let styles = [#("display", "flex"), #("justify-content", "space-between")]

  html.div(
    [attribute.styles(styles)],
    containers
      |> list.map(fn(container) {
        html.div([attribute.styles(styles)], [
          todo as "draw container and arrow to point at it ",
        ])
      }),
  )
}

fn draw_svg_arrow(
  width: #(String, String),
  height: #(String, String),
) -> Element(Msg) {
  let steps = [
    // go to x0 y0
    "M0 0",
    // line to curve start
    "L0 100",
    // relative curve 
    "c0 2 2 2 6 2",
    // upper arrow line
    "l-3 1",
    // move to arrow tip
    "M-3 1",
    // lower arrow line
    "L-3 -1",
  ]

  html.svg(
    [
      attribute.styles([width, height]),
      attribute.attribute("preserveAspectRatio", "xMidYMax slice"),
    ],
    [svg.path([attribute.attribute("d", string.join(steps, " "))])],
  )
}

fn view_container(
  container: Container,
  selector: fn(Container, String) -> Selected,
) -> Element(Msg) {
  let status_color = case container.data.state {
    "exited" -> red
    "running" -> green
    _ -> white
  }

  html.div(
    [
      event.on_click(UserSelectedItem(selector(container, ""))),
      attribute.class("clickable"),
      attribute.id("vm-container"),
      attribute.styles([
        #("display", "flex"),
        #("flex-direction", "row"),
        #("justify-content", "space-between"),
        #("margin", "2px"),
      ]),
    ],
    [
      html.div([], [
        html.text(
          list.fold(container.data.names, "", fn(a, b) { a <> " " <> b }),
        ),
      ]),
      html.div(
        [attribute.styles([#("text-align", "end"), #("color", status_color)])],
        [html.text(container.data.state)],
      ),
    ],
  )
}
