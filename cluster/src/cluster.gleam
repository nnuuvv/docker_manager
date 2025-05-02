import barnacle
import envoy
import gleam/erlang/atom
import gleam/erlang/process
import gleam/io
import gleam/list
import gleam/otp/supervisor
import gleam/result
import gleam/string

pub fn main() -> Nil {
  let assert Ok(hosts) =
    envoy.get("HOSTS")
    |> result.replace_error("HOSTS environment variable is not set")
    |> result.map(fn(host_string) {
      host_string
      |> string.split(",")
    })

  let update_receiver_subject = process.new_subject()

  let barnacle =
    barnacle.epmd(
      hosts
      |> list.map(fn(host) { "cluster@" <> host })
      |> list.map(atom.create_from_string)
      |> echo,
    )
    |> barnacle.with_poll_interval(5000)
    |> barnacle.with_name("cluster")
    |> barnacle.with_listener(update_receiver_subject)

  // create a subject to receive the child process later
  let self = process.new_subject()

  // start the child process under a supervisor
  let barnacle_worker = barnacle.child_spec(barnacle, self)
  let assert Ok(_) = supervisor.start(supervisor.add(_, barnacle_worker))

  // get a subject to send messages to the child process
  let assert Ok(update_sender_subject) = process.receive(self, 10_000)

  let _ = barnacle.refresh(update_sender_subject, 5000)

  loop(update_receiver_subject)

  process.sleep_forever()
}

fn loop(subj: process.Subject(barnacle.BarnacleResponse(Nil))) -> b {
  let message = process.receive_forever(subj)
  case message {
    barnacle.RefreshResponse(Ok(val)) -> {
      let _ =
        val
        |> list.map(atom.to_string)
        |> string.join(",")
        |> string.append(" Connected. This is a refresh. \n")
        |> echo
      Nil
    }
    _ -> Nil
  }

  loop(subj)
}
