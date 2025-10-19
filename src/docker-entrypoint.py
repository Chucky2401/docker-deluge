import socket, struct
import re, subprocess
import signal, time
import netifaces as ni
import os.path
import sh.util

def get_default_gateway():
    # with open("/proc/net/route") as fh:
    #     for line in fh:
    #         fields = line.strip().split()
    #         if fields[1] != '00000000' or not int(fields[3], 16) & 2:
    #             continue

    #         return socket.inet_ntoa(struct.pack("<L", int(fields[2], 16)))
    output = subprocess.check_output(["ip", "route", "show", "default"]).decode()

    for part in output.split():
        if part == "via":
            return output.split()[output.split().index("via") + 1]

# -------------------------------------------------------------------------------------------------------------------- #

def get_tun0_ip_address():
    ip = ni.ifaddresses('tun0')[ni.AF_INET][0]['addr']

    return ip

# -------------------------------------------------------------------------------------------------------------------- #

def set_listen_interface(ip):
    # ip = get_tun0_ip_address()
    pattern = re.compile(r'"listen_interface"\s*:\s*"(\d+\.\d+\.\d+\.\d+)?"')
    new_pattern = f'"listen_interface": "{ip}"'

    with open("/deluge-conf/core.conf", "r") as f:
        text = f.read()

    new_text = pattern.sub(new_pattern, text)

    with open("/deluge-conf/core.conf", "w") as f:
        f.write(new_text)

# -------------------------------------------------------------------------------------------------------------------- #

def set_outgoing_interface(ip):
    # ip = get_tun0_ip_address()
    pattern = re.compile(r'"outgoing_interface"\s*:\s*"(\d+\.\d+\.\d+\.\d+)?"')
    new_pattern = f'"outgoing_interface": "{ip}"'

    with open("/deluge-conf/core.conf", "r") as f:
        text = f.read()

    new_text = pattern.sub(new_pattern, text)

    with open("/deluge-conf/core.conf", "w") as f:
        f.write(new_text)

# -------------------------------------------------------------------------------------------------------------------- #

def get_default_interface():
    # name_pattern = r'^(eth\w+)\s'
    # pattern = re.compile(name_pattern, flags=re.MULTILINE)
    # ifconfig = subprocess.check_output("ifconfig").decode()
    # interfaces = pattern.findall(ifconfig)
    interface = 'eth0'
    output = subprocess.check_output(["ip", "route", "show", "default"]).decode()

    for part in output.split():
        if part == "dev":
            inteface = output.split()[output.split().index("dev") + 1]

    return interface

# -------------------------------------------------------------------------------------------------------------------- #

def set_static_route(address, netmask, gateway, iface="eth0"):
    routed = subprocess.run(["/sbin/ip", "route", "add", "to", address + "/" + netmask, "via", gateway, "dev", iface])

    return routed.returncode

# -------------------------------------------------------------------------------------------------------------------- #

def start_openvpn():
    if not os.path.isfile("/.openvpn/logs/openvpn.log"):
        shutil.move("/.openvpn/logs/openvpn.log", "/.openvpn/logs/openvpn.log.old")

    openvpn = subprocess.Popen(["/usr/sbin/openvpn", "--config", "/.openvpn/Sweden.ovpn", "--log-append", "/.openvpn/logs/openvpn.log", "--daemon"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    return openvpn

# -------------------------------------------------------------------------------------------------------------------- #

def start_deluge():
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

    print("Test '/deluge-conf/core.conf'...")
    if not os.path.isfile("/deluge-conf/core.conf"):
        shutil.copyfile("/entrypoint/core.conf", "/deluge-conf/core.conf")

    print("Get tun0 ip address...")
    ip = get_tun0_ip_address()

    print(f"*************************************************")
    print(f"*                                 ")
    print(f"*     Your tun0 ip address is {ip}")
    print(f"*                                 ")
    print(f"*************************************************")

    print("Set incoming interface...")
    set_listen_interface(ip)
    set_outgoing_interface(ip)

    print("Starting Deluge Server...")
    deluged = start_deluge()

    killer.processOpenVPN = openVPN
    killer.processDeluged = deluged

    tailLog = subprocess.Popen(["tail", "-n", "1", "-f", "/deluge-conf/deluged.log"], cwd="/deluge-conf")

    print("All done! Have fun!")

    while not killer.kill_now:
        time.sleep(1)


if __name__ == '__main__':
    main()

    quit(0)
