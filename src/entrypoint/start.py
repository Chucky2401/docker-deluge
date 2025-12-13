import socket, struct
import re, subprocess
import signal, time
import netifaces as ni
import os.path
import shutil


def validate_deluge_loglevel(value: str):
    valideValue = (
        "none",
        "info",
        "warning",
        "error",
        "debug"
    )

    return value if value in valideValue else "error"

# -------------------------------------------------------------------------------------------------------------------- #

def get_default_gateway():
    output = subprocess.check_output(["ip", "route", "show", "default"]).decode()

    for part in output.split():
        if part == "via":
            return output.split()[output.split().index("via") + 1]

# -------------------------------------------------------------------------------------------------------------------- #

def check_tun0():
    interfaces = ni.interfaces()
    if 'tun0' in interfaces:
        return True
    else:
        return False

# -------------------------------------------------------------------------------------------------------------------- #

def wait_for_tun0(max_attempts=5, delay=5):
    """
    Vérifie la présence de tun0 avec plusieurs tentatives.

    Args:
        max_attempts: Nombre maximum de tentatives (défaut: 5)
        delay: Délai en secondes entre chaque tentative (défaut: 5)

    Returns:
        bool: True si tun0 est trouvé, False sinon
    """
    for attempt in range(1, max_attempts + 1):

        if check_tun0():
            return True

        if attempt < max_attempts:
            time.sleep(delay)

    return False

# -------------------------------------------------------------------------------------------------------------------- #

def get_tun0_ip_address():
    ip = ni.ifaddresses('tun0')[ni.AF_INET][0]['addr']

    return ip

# -------------------------------------------------------------------------------------------------------------------- #

def set_listen_interface(ip):
    pattern = re.compile(r'"listen_interface"\s*:\s*"(\d+\.\d+\.\d+\.\d+)?"')
    new_pattern = f'"listen_interface": "{ip}"'

    with open("/deluge-conf/core.conf", "r") as f:
        text = f.read()

    new_text = pattern.sub(new_pattern, text)

    with open("/deluge-conf/core.conf", "w") as f:
        f.write(new_text)

# -------------------------------------------------------------------------------------------------------------------- #

def set_outgoing_interface(ip):
    pattern = re.compile(r'"outgoing_interface"\s*:\s*"(\d+\.\d+\.\d+\.\d+)?"')
    new_pattern = f'"outgoing_interface": "{ip}"'

    with open("/deluge-conf/core.conf", "r") as f:
        text = f.read()

    new_text = pattern.sub(new_pattern, text)

    with open("/deluge-conf/core.conf", "w") as f:
        f.write(new_text)

# -------------------------------------------------------------------------------------------------------------------- #

def get_daemon_port():
    pattern = re.compile(r'"daemon_port"\s*:\s*(\d+)?')

    with open("/deluge-conf/core.conf", "r") as f:
        text = f.read()

    match = pattern.search(text)

    if match:
        return match[1]

    return None

# -------------------------------------------------------------------------------------------------------------------- #

def set_daemon_port(port):
    pattern = re.compile(r'"daemon_port"\s*:\s*(\d+)?')
    new_pattern = f'"daemon_port": {port}'

    with open("/deluge-conf/core.conf", "r") as f:
        text = f.read()

    new_text = pattern.sub(new_pattern, text)

    with open("/deluge-conf/core.conf", "w") as f:
        f.write(new_text)

# -------------------------------------------------------------------------------------------------------------------- #

def get_default_interface():
    interface = 'eth0'
    output = subprocess.check_output(["ip", "route", "show", "default"]).decode()

    for part in output.split():
        if part == "dev":
            inteface = output.split()[output.split().index("dev") + 1]

    return interface

# -------------------------------------------------------------------------------------------------------------------- #

# def set_static_route(address, netmask, gateway, iface="eth0"):
def set_static_route(localNetwork, gateway, iface="eth0"):
    pattern = re.compile(r'^\d{,3}\.\d{,3}\.\d{,3}\.\d{,3}\/\d{,2}')

    if not pattern.search(localNetwork):
        print("❌ Please provide a valid value for LOCAL_NETWORK, eg: 192.168.1.0/24")
        quit(0)

    address, netmask = localNetwork.split('/')

    routed = subprocess.run(["/sbin/ip", "route", "add", "to", address + "/" + netmask, "via", gateway, "dev", iface])

    return routed.returncode

# -------------------------------------------------------------------------------------------------------------------- #

def start_openvpn(ovpnFile: str):
    if not os.path.exists("/.openvpn/logs"):
        os.makedirs("/.openvpn/logs")

    if os.path.isfile("/.openvpn/logs/openvpn.log"):
        shutil.move("/.openvpn/logs/openvpn.log", "/.openvpn/logs/openvpn.log.old")

    print(f"  -> Using {ovpnFile} file...")

    openvpn = subprocess.Popen(["/usr/sbin/openvpn", "--config", ovpnFile, "--auth-user-pass", "/var/lib/deluge/vpn", "--log-append", "/.openvpn/logs/openvpn.log", "--daemon"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    return openvpn

# -------------------------------------------------------------------------------------------------------------------- #

def start_deluged(loglevel = "info"):
    deluged = subprocess.Popen(["/usr/bin/python3", "/usr/bin/deluged", "-c", "/deluge-conf", "--logfile=/deluge-conf/deluged.log", "--loglevel", loglevel, "-U", "deluge", "-g", "deluge", "-d"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    return deluged

# -------------------------------------------------------------------------------------------------------------------- #

def start_deluge_web():
    delugeWeb = subprocess.Popen(["/usr/bin/python3", "/usr/bin/deluge-web", "-c", "/deluge-conf", "--logfile=/deluge-conf/deluge-web.log", "--loglevel=info", "-U", "deluge", "-g", "deluge"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    return delugeWeb

# -------------------------------------------------------------------------------------------------------------------- #

class GracefulKiller:
    kill_now         = False
    processOpenVPN   = None
    processDeluged   = None
    processDelugeWeb = None

    def __init__(self):
        signal.signal(signal.SIGINT, self.exit_gracefully)
        signal.signal(signal.SIGTERM, self.exit_gracefully)

    def exit_gracefully(self, signum, frame):
        self.processDelugeWeb.terminate()
        self.processDelugeWeb.communicate()

        self.processDeluged.terminate()
        self.processDeluged.communicate()

        self.processOpenVPN.terminate()
        self.processOpenVPN.communicate()

        self.kill_now = True

# -------------------------------------------------------------------------------------------------------------------- #

def main():
    killer = GracefulKiller()

    retryMax = 5
    waiting  = 5
    retries  = 0

    daemonPort = os.getenv('DELUGE_DAEMON_PORT', 58846)

    delugeLogLevel = validate_deluge_loglevel(os.environ['DELUGE_LOGLEVEL'])

    gateway     = get_default_gateway()
    iface       = get_default_interface()
    staticRoute = set_static_route(os.environ['LOCAL_NETWORK'], gateway, iface)

    if staticRoute != 0:
        print("Route has not been set!")
        quit(1)

    print("ℹ️ Test '/deluge-conf/core.conf'...")
    if not os.path.isfile("/deluge-conf/core.conf"):
        print("⚠️ Copy default 'core.conf'...")
        try:
            shutil.copyfile("/template/core.conf", "/deluge-conf/core.conf")
        except Exception as e:
            print(f"Cannot copy default 'core.conf': {e}")
            quit(1)
    print("✅ Default 'core.conf' has been copied!\n")

    print("ℹ️ Starting OpenVPN...")
    openVPN = start_openvpn(os.environ['VPN_FILE'])

    print("🔄 Waiting for tun0 interface...")
    if not wait_for_tun0(max_attempts=retryMax, delay=waiting):
        print("❌ Cannot find tun0 interface!")
        quit(1)

    print("ℹ️ Get tun0 ip address...")
    ip = get_tun0_ip_address()

    print(f"*************************************************")
    print(f"*                                 ")
    print(f"*     Your tun0 ip address is {ip}")
    print(f"*                                 ")
    print(f"*************************************************\n")

    print("ℹ️ Set incoming interface in Deluge 'core.conf'...")
    try:
        set_listen_interface(ip)
        set_outgoing_interface(ip)
    except Exception as e:
        print(f"Cannot set ip address interface: {e}")
        quit(1)
    print("✅ Incoming interface has been set in Deluge 'core.conf'!\n")

    if daemonPort != 58846 and daemonPort != get_daemon_port():
        try:
            print(f"ℹ️ Setting daemon port to {daemonPort}...")
            set_daemon_port(daemonPort)
            print("✅ Port has been set\n")
        except Exception as e:
            print(f"❌ Daemon has not been set, keep default port 58846.")
            print(f"Error: {e}\n")

    print("ℹ️ Starting Deluge Server...")
    deluged   = start_deluged(delugeLogLevel)
    print("ℹ️ Starting Deluge Web interface...")
    time.sleep(3)
    delugeWeb = start_deluge_web()

    killer.processOpenVPN   = openVPN
    killer.processDeluged   = deluged
    killer.processDelugeWeb = delugeWeb

    print("✅ All done! Have fun!\n")

    tailLog = subprocess.Popen(["tail", "-n", "+1", "-f", "/deluge-conf/deluged.log"], cwd="/deluge-conf")


    while not killer.kill_now:
        time.sleep(1)


if __name__ == '__main__':
    main()

    quit(0)
