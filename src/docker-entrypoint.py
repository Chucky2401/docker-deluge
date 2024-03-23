import socket, struct
import re, subprocess
import signal, time

def get_default_gateway():
    with open("/proc/net/route") as fh:
        for line in fh:
            fields = line.strip().split()
            if fields[1] != '00000000' or not int(fields[3], 16) & 2:
                # If not default route or not RTF_GATEWAY, skip it
                continue

            return socket.inet_ntoa(struct.pack("<L", int(fields[2], 16)))

# -------------------------------------------------------------------------------------------------------------------- #

def get_default_interface():
    name_pattern = "^(eth\w+)\s"
    pattern = re.compile(name_pattern, flags=re.MULTILINE)
    ifconfig = subprocess.check_output("ifconfig").decode()
    interfaces = pattern.findall(ifconfig)

    return interfaces[0]

# -------------------------------------------------------------------------------------------------------------------- #

def set_static_route(address, netmask, gateway, iface="eth0"):
    routed = subprocess.run(["/sbin/ip", "route", "add", "to", address + "/" + netmask, "via", gateway, "dev", iface])

    return routed.returncode

# -------------------------------------------------------------------------------------------------------------------- #

def start_openvpn():
    #/usr/sbin/openvpn --config /.openvpn/Sweden.ovpn --log-append /.openvpn/logs/openvpn.log --daemon
    openvpn = subprocess.Popen(["/usr/sbin/openvpn", "--config", "/.openvpn/Sweden.ovpn", "--log-append", "/.openvpn/logs/openvpn.log", "--daemon"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    return openvpn

# -------------------------------------------------------------------------------------------------------------------- #

def start_deluge():
    #/usr/bin/python3 /usr/bin/deluged -c /config --logfile=/config/deluged.log --loglevel=info
    deluged = subprocess.Popen(["/usr/bin/python3", "/usr/bin/deluged", "-c", "/deluge-conf", "--logfile=/deluge-conf/deluged.log", "--loglevel=info", "-d"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    return deluged

# -------------------------------------------------------------------------------------------------------------------- #

class GracefulKiller:
    kill_now       = False
    processOpenVPN = None
    processDeluged = None

    def __init__(self):
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)

    #def exit_gracefully(self, *args):
    def exit_gracefully(self, signum, frame):
        self.processDeluged.terminate()
        self.processDeluged.communicate()

        self.processOpenVPN.terminate()
        self.processOpenVPN.communicate()

        self.kill_now = True

# -------------------------------------------------------------------------------------------------------------------- #

def main():
    killer = GracefulKiller()

    gateway     = get_default_gateway()
    iface       = get_default_interface()
    staticRoute = set_static_route("192.168.1.0", "24", gateway, iface)

    if staticRoute != 0:
        print("Route has not been set!")
        quit(1)

    print("Starting OpenVPN...")
    openVPN = start_openvpn()
    time.sleep(15)

    print("Starting Deluge Server...")
    deluged = start_deluge()

    killer.processOpenVPN = openVPN
    killer.processDeluged = deluged

    print("All done! Have fun!")

    while not killer.kill_now:
        time.sleep(1)


if __name__ == '__main__':
    main()

    quit(0)
