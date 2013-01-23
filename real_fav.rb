# -*- coding: utf-8 -*-
require 'serialport'

Plugin.create(:real_fav) do
  class XBeeAPI
    BAUD_RATE = 9600
    ADDR16_BROADCAST = [0xFF, 0xFE]

    def initialize(port, addr64)
      @addr64 = addr64.split(':').map {|s| s.hex}
      @addr16 = ADDR16_BROADCAST
      @sp = SerialPort.new(port, BAUD_RATE)
    end

    def send(data)
      length = data.length
      checksum = 0xff - data.inject(:+) % 256
      data = [data.map{|i| ("%02x" % i).gsub(/(7e|7d|11|13)/){"7d" + ("%02x" % ($1.hex ^ 0x20))}}.join].pack("H*").unpack("C*")
      data = [0x7e, length / 256, length % 256, *data, checksum]
      notice(data.map{|i| "%02x" % i}.join)
      @sp.write(data.pack("C*"))
    end

    def remote_request(option, command, param)
      frame_type = 0x17
      frame_id = 0x01
      command = command.unpack("C2")
      data = [frame_type, frame_id, *@addr64, *@addr16, option, *command, param]
      send(data)
    end

    def led_off
      remote_request(0x02, "D1", 0x04)
    end

    def led_on
      remote_request(0x02, "D1", 0x05)
    end

    def led_blink(times)
      times.times do
	led_on
	sleep(0.3)
	led_off
	sleep(0.3)
      end
    end

    def close
      @sp.close
    end
  end

  on_favorite do |service, user_obj, message|
    if UserConfig[:real_fav_notify_faved] && !user_obj.is_me?
      xbee = XBeeAPI.new(UserConfig[:xbee_port], UserConfig[:end_device_addr])
      xbee.led_blink(3)
      xbee.close
      xbee = nil
    end
  end

  settings 'リアルふぁぼ' do
    boolean "ふぁぼられを通知", :real_fav_notify_faved
    input "シリアルポート", :xbee_port
    input "XBeeエンドデバイスのアドレス(64bit)", :end_device_addr
  end
end
