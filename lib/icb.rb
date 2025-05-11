# =======================================
# Charlotte's ICB Client Library for Ruby
# =======================================
#
# Copyright 2016, 2017, 2018 Charlotte Koch <dressupgeekout@gmail.com>
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice, this
# list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright notice,
# this list of conditions and the following disclaimer in the documentation
# and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

require 'socket'
require 'stringio'

module Icb
  API_VERSION = "0.0.1".freeze
end


module Icb::MessageTypes
  LOGIN_PACKET = 'a'.freeze
  OPEN_MESSAGE = 'b'.freeze
  PERSONAL_MESSAGE = 'c'.freeze
  STATUS_MESSAGE = 'd'.freeze
  ERROR_MESSAGE = 'e'.freeze
  IMPORTANT_MESSAGE = 'f'.freeze
  EXIT_PACKET = 'g'.freeze
  COMMAND_PACKET = 'h'.freeze
  COMMAND_OUTPUT_PACKET = 'i'.freeze
  PROTOCOL_PACKET = 'j'.freeze
  BEEP_PACKET = 'k'.freeze
  PING_PACKET = 'l'.freeze
  PONG_PACKET = 'm'.freeze
  NOOP_PACKET = 'n'.freeze
end


module Icb::MessageMixins
  module LoginPacket
  end

  module OpenMessage
    def from; return @fields[0]; end
    def body; return @fields[1]; end
  end

  module PersonalMessage 
    include OpenMessage
  end

  module StatusMessage
    def category; return @fields[0]; end
    def body; return @fields[1]; end
  end

  module ErrorMessage
    def body; return @fields[0]; end
  end

  module ImportantMessage
    include StatusMessage
  end

  module ExitPacket
  end

  module CommandPacket
  end

  # XXX implementme
  module CommandOutputPacket
  end

  module ProtocolPacket
    def level; return @fields[0]; end
    def host_id; return @fields[1]; end
    def server_id; return @fields[2]; end
  end

  module BeepPacket
    def from; return @fields[0]; end
  end

  module PingPacket
    def identifier; return @fields[0]; end
  end

  module PongPacket
    include PingPacket
  end

  module NoopPacket
  end
end # module MessageMixins


class Icb::Message
  include Icb::MessageTypes

  attr_reader :length, :type, :fields

  def initialize(length: 2, type: NOOP_PACKET, fields: [])
    @length = length
    @type = type
    @fields = fields
  end

  def refine
    return case @type
      when LOGIN_PACKET; self.extend(Icb::MessageMixins::LoginPacket);
      when OPEN_MESSAGE; self.extend(Icb::MessageMixins::OpenMessage);
      when PERSONAL_MESSAGE; self.extend(Icb::MessageMixins::PersonalMessage);
      when STATUS_MESSAGE; self.extend(Icb::MessageMixins::StatusMessage);
      when ERROR_MESSAGE; self.extend(Icb::MessageMixins::ErrorMessage);
      when IMPORTANT_MESSAGE; self.extend(Icb::MessageMixins::ImportantMessage);
      when EXIT_PACKET; self.extend(Icb::MessageMixins::ExitPacket);
      when COMMAND_PACKET; self.extend(Icb::MessageMixins::CommandPacket);
      when COMMAND_OUTPUT_PACKET; self.extend(Icb::MessageMixins::CommandOutputPacket);
      when PROTOCOL_PACKET; self.extend(Icb::MessageMixins::ProtocolPacket);
      when BEEP_PACKET; self.extend(Icb::MessageMixins::BeepPacket);
      when PING_PACKET; self.extend(Icb::MessageMixins::PingPacket);
      when PONG_PACKET; self.extend(Icb::MessageMixins::PongPacket);
      when NOOP_PACKET; self.extend(Icb::MessageMixins::NoopPacket);
      else; nil
    end
  end
end


module Icb::Helpers
  include Icb::MessageTypes

  # Can't use ::number_to_char here for some reason.
  FIELD_JOINER = [1].pack("C")

  def strtype(type)
    return case type
      when LOGIN_PACKET; "LOGIN_PACKET";
      when OPEN_MESSAGE; "OPEN_MESSAGE";
      when PERSONAL_MESSAGE; "PERSONAL_MESSAGE";
      when STATUS_MESSAGE; "STATUS_MESSAGE";
      when ERROR_MESSAGE; "ERROR_MESSAGE";
      when IMPORTANT_MESSAGE; "IMPORTANT_MESSAGE";
      when EXIT_PACKET; "EXIT_PACKET";
      when COMMAND_PACKET; "COMMAND_PACKET";
      when COMMAND_OUTPUT_PACKET; "COMMAND_OUTPUT_PACKET";
      when PROTOCOL_PACKET; "PROTOCOL_PACKET";
      when BEEP_PACKET; "BEEP_PACKET";
      when PING_PACKET; "PING_PACKET";
      when PONG_PACKET; "PONG_PACKET";
      when NOOP_PACKET; "NOOP_PACKET";
      else; nil;
    end
  end
  private(:strtype)

  def parse_data(data)
    length = data.read(1).unpack("C")[0]
    type = data.read(1)
    fields = data.read(length-1).split(FIELD_JOINER)
    return Icb::Message.new(length: length, type: type, fields: fields)
  end

  def receive_response(socket)
    msg, remote_addrinfo, rflags, controls = socket.recvmsg
    return {
      :data => StringIO.new(msg),
      :addrinfo => remote_addrinfo,
      :rflags => rflags,
      :controls => controls,
    }
  end

  def number_to_char(n)
    return [n].pack("C")
  end
end


class Icb::ClientConnection
  include Icb::Helpers
  include Icb::MessageTypes

  DEFAULT_HOST = "127.0.0.1".freeze
  DEFAULT_PORT = 7326

  attr_reader :host, :port, :socket

  def initialize(**kwargs)
    @host = kwargs[:host] || DEFAULT_HOST
    @port = kwargs[:port] || DEFAULT_PORT
    connect
  end

  def to_s
    return sprintf("%s:%d", @host, @port)
  end

  def connect
    @socket = TCPSocket.open(@host, @port)
  end
  private(:connect)

  def disconnect
    @socket.close
  end

  # Note it is the caller's responsibility to arrange the fields in the
  # order expected by the protocol.
  def buildpayload(type, *fields)
    pretotal = type + fields.join(FIELD_JOINER)
    return number_to_char(pretotal.length+1) + pretotal + "\x00"
  end
  private(:buildpayload)

  def login(**kwargs)
    fields = [
      kwargs[:login_id], kwargs[:nickname], kwargs[:default_group],
      kwargs[:command], kwargs[:password], kwargs[:group_status],
      kwargs[:protocol_level]
    ]
    @socket.sendmsg(buildpayload(LOGIN_PACKET, *fields.compact))
  end

  def open_message(msg)
    @socket.sendmsg(buildpayload(OPEN_MESSAGE, msg))
  end
  alias_method :say, :open_message

  # XXX Untested.
  def command_packet(command: "", arguments: nil, message_id: nil)
    fields = [command, arguments, message_id]
    @socket.sendmsg(buildpayload(COMMAND_PACKET, *fields.compact))
  end

  # XXX I have no idea what the "protocol level" should be :(
  def protocol_packet(host_id: nil, client_id: nil)
    fields = [number_to_char(0), host_id, client_id]
    @socket.sendmsg(buildpayload(PROTOCOL_PACKET, *fields.compact))
  end

  def ping(identfier: nil)
    fields = identfier ? [identifier] : []
    @socket.sendmsg(buildpayload(PING_PACKET, *fields))
  end

  def pong(identifier: nil)
    fields = identfier ? [identfier] : []
    @socket.sendmsg(buildpayload(PONG_PACKET, *fields))
  end

  def noop
    @socket.sendmsg(buildpayload(NOOP_PACKET))
  end
end
