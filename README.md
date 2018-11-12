# ICB client library for Ruby

This is a free, open-source, pure Ruby implementation of a client library for
the old ICB chat protocol ("Internet Citizen's Band"). It provides an
object-oriented API to let you easily send and receive messages to and/or from
a ICB server. It is implemented in only a single source file and requires MRI
2.0.0 or greater (or any Ruby version which supports keyword arguments).


## Development status

Most of the interesting bits have been implemented. Most notably missing is an
object-oriented interface to the different kinds of "command output types"
("co", "ec", "wl", etc.)


## Example script

```ruby
require 'icb'
include Icb::Helpers
include Icb::MessageTypes

client = nil # (scope)
trap("INT") { exit }
at_exit { client.disconnect }

client = Icb::ClientConnection.new host: "127.0.0.1", port: Icb::ClientConnection::DEFAULT_PORT
client.login(login_id: ENV["USER"], nickname: "moana", default_group: "motonui", command: "login")

loop do
t msg = parse_data(receive_response(client.socket)[:data]).refine
  if msg.type == OPEN_MESSAGE and msg.body =~ /^moana:/
    client.say("Hey, #{msg.from}!")
  end
end
```


## License

This module is released under a 2-clause BSD-style license. Refer to "icb.rb"
for details.
