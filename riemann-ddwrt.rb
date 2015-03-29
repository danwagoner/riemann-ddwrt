# riemann-ddwrt
# author: Dan Wagoner - nerdybynature.com
# This script gathers stats from DDWRT and publishes them to riemann. It currently only gathers
# throughput stats on the internet-facing interface.

require 'riemann/client'
require 'net/http'
require 'daemons'

Daemons.daemonize

riemann_ip = '127.0.0.1'
riemann_port = '5555'
ddwrt_ip = '127.0.0.1'
ddwrt_user = 'username'
ddwrt_pass = 'password'
interval = 2
debug = false

$rx_bytes_prev = 0
$tx_bytes_prev = 0
uri = URI("http://#{ddwrt_ip}/fetchif.cgi?vlan2")
c = Riemann::Client.new host: "#{riemann_ip}", port: "#{riemann_port}", timeout: 5
req = Net::HTTP::Get.new(uri)

loop do
	req.basic_auth ddwrt_user, ddwrt_pass
	res = Net::HTTP.start(uri.hostname, uri.port) {|http|
  		http.request(req)
	}		

	results = res.body.split

	$rx_bytes = results[6].split(':')[1].to_i
	$rx_packets = results[7].to_i
	$rx_errs = results[8].to_i
	$tx_bytes = results[14].to_i
	$tx_packets = results[15].to_i
	$tx_errs = results[16].to_i
	
	#calculate throughput
	if $rx_bytes > $rx_bytes_prev then
		$rx_tp = (($rx_bytes.to_f-$rx_bytes_prev.to_f)/131072/interval).round(2)
        end
	if $tx_bytes > $tx_bytes_prev then
		$tx_tp = (($tx_bytes.to_f-$tx_bytes_prev.to_f)/131072/interval).round(2)
	end

	#debug
	if debug == true then
		puts "rx_bytes: #{$rx_bytes}"
		puts "rx_packets: #{$rx_packets}"
		puts "rx_errs: #{$rx_errs}"
		puts "tx_bytes: #{$tx_bytes}"
		puts "tx_packets: #{$tx_packets}"
		puts "tx_errs: #{$tx_errs}"
		puts "rx_bytes_prev: #{$rx_bytes_prev}"
		puts "tx_bytes_prev: #{$tx_bytes_prev}"
		puts "rx_tp: #{$rx_tp}"
		puts "tx_tp: #{$tx_tp}"
	end

	#send metrics to riemann
	c.tcp << {service: 'rx_bytes', metric: $rx_bytes, tags: ["router"]}
	c.tcp << {service: 'rx_packets', metric: $rx_packets, tags: ["router"]}
	c.tcp << {service: 'rx_errs', metric: $rx_errs, tags: ["router"]}
	c.tcp << {service: 'tx_bytes', metric: $tx_bytes, tags: ["router"]}
	c.tcp << {service: 'tx_packets', metric: $tx_packets, tags: ["router"]}
	c.tcp << {service: 'tx_errs', metric: $tx_errs, tags: ["router"]}
	c.tcp << {service: 'rx_tp', metric: $rx_tp, tags: ["throughput"]}
	c.tcp << {service: 'tx_tp', metric: $tx_tp, tags: ["throughput"]}
	
	#capture stats for throughput calculation next go around
	$rx_bytes_prev = $rx_bytes
        $tx_bytes_prev = $tx_bytes

	sleep(interval)
end
