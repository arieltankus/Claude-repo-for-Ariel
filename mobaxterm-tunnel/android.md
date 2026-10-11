# Browse through the server from an Android phone or tablet

On Android the pieces differ from the PC: MobaXterm does not exist for
Android, and Chrome for Android has no proxy setting at all. The idea stays
the same. An SSH app opens a tunnel to the server and offers a SOCKS proxy on
the phone at `127.0.0.1:1080`. A browser that can use a SOCKS proxy then sends
its traffic through the tunnel, so every page the server can reach, the phone
can reach too.

GlobalProtect stays as it is. The tunnel is an ordinary SSH connection inside
the VPN, and nothing has to be installed on the server.

| Browser on the phone | Through the tunnel? | See |
| --- | --- | --- |
| Firefox + FoxyProxy extension | Yes, every site, like the PC setup | Part 2 |
| Cromite (open-source Chromium) | Has a built-in proxy page. Not verified by me | Part 3 |
| Chrome | One site at a time, through a local port forward | Part 4 |

Why not Chrome directly: Chrome for Android cannot be given a proxy without a
rooted phone. Apps that push all traffic through a SOCKS proxy, such as
SocksDroid, work as a VPN, and Android allows only one VPN at a time, so they
cannot run next to GlobalProtect. The Wi-Fi proxy setting of Android takes only
HTTP proxies and is per network, so it does not help either.

## 0. Already using the "Mobaxterm SSH" app from Google Play?

That app (package `com.csgroup.ssh`, developer "A389 St") is not made by
Mobatek, the company behind the Windows MobaXterm. Mobatek publishes Windows
software only. The Play Store app borrows the name, shows ads, and its store
page lists SSH, X11, RDP, VNC and Telnet plus "tunnel networking", without
saying which tunnel types it offers.

Check it before installing anything else: long-press your saved server in its
host list and look for an entry such as **Edit port forwards** or **Tunnels**.
If it lets you add a forward of type **Dynamic (SOCKS)** with source port
`1080`, use that and skip to Part 2. If it offers only local forwards, Part 4
works with it. If it has no port forwarding at all, install ConnectBot as
described next. Both apps can stay installed side by side.

One thing to weigh: your university password goes into that app, and its
code is closed and its publisher unknown. ConnectBot and Termux are open
source, which is why this guide uses ConnectBot.

## 1. The tunnel: ConnectBot

ConnectBot is free and open source, on Google Play and F-Droid. Termius also
supports dynamic port forwarding, and Termux users can simply run
`ssh -N -D 1080 USER@SERVER` after `pkg install openssh`.

1. Connect GlobalProtect.
2. Install ConnectBot and open it. In the field at the bottom type
   `USER@SERVER` (add `:PORT` if the server does not use port 22) and press
   Enter. Accept the host key and type your password. You get a terminal.
   Type `exit`. The host is now saved in the list.
3. Long-press the host and choose **Edit port forwards**. Open the menu and
   choose **Add port forward**. Nickname `socks`, Type **Dynamic (SOCKS)**,
   Source port `1080`, destination empty. Tap **Create port forward**.
4. Long-press the host again and choose **Edit host**. Switch **Start shell
   session** off and **Stay connected** on. Connecting then opens no terminal
   and the connection only carries the tunnel.
5. Tap the host to connect and enter your password. The screen stays idle.
   The proxy is live at `127.0.0.1:1080` as long as ConnectBot shows its
   "connected" notification.
6. Android may kill background connections. In Android Settings, Apps,
   ConnectBot, Battery, choose **Unrestricted**.

To stop the tunnel, disconnect from the ConnectBot notification or from its
menu.

## 2. Firefox with FoxyProxy

1. Install Firefox from Google Play.
2. Open the Firefox menu, **Extensions**, search for FoxyProxy and add
   **FoxyProxy Basic** (Standard works as well).
3. Open the FoxyProxy options and add a proxy: Type **SOCKS5**, Hostname
   `127.0.0.1`, Port `1080`, and switch **Proxy DNS** on. Save.
4. Tap the FoxyProxy icon in the extensions menu and select that proxy.
   Browse. Select **Disable** to return to normal browsing.

With Proxy DNS on, internal host names are resolved by the server, exactly
like the PC setup.

## 3. Cromite, a Chrome-like option

Cromite is an open-source Chromium for Android, installed as an APK from
https://github.com/uazo/cromite/releases (arm64 fits nearly every phone). It
has a built-in proxy page: open Settings, Privacy and security, Proxy
configuration, or type `chrome://proxy` in the address bar. Choose manual
configuration and enter `socks5://127.0.0.1:1080` as the proxy for all
protocols. I could not verify this page on a device. If it refuses a SOCKS
entry, use Firefox from Part 2.

## 4. Chrome, one site at a time

Chrome has no proxy setting, but a *local* port forward makes one internal
site appear on the phone itself.

1. In ConnectBot: **Edit port forwards**, **Add port forward**, Type
   **Local**, Source port `8080`, Destination `internal.host:80`, meaning the
   site's host name and port as seen from the server.
2. Connect, then open `http://localhost:8080/` in Chrome.

For a program running on the server itself, for example Jupyter on port 8888,
the destination is `localhost:8888` and Chrome opens `http://localhost:8888/`.

Limits: an HTTPS site gives a certificate warning for "localhost" that you can
click through; a site that redirects to its own host name breaks; each site
needs its own forward.

## 5. The original goal: the server's screen on the phone

To see a Firefox that runs *on the server*, use VNC rather than X11:

1. On the server, start a VNC desktop with `vncserver` (TigerVNC). The first
   run asks for a VNC password. Note the display number, usually `:1`, which
   means port 5901.
2. In ConnectBot add a **Local** forward: Source port `5901`, Destination
   `localhost:5901`, and connect.
3. In a VNC viewer app such as AVNC or RealVNC Viewer connect to
   `127.0.0.1:5901`. You get the whole remote desktop, including Firefox.

X11 forwarding is possible on Android too, with Termux and the XServer XSDL
app, but VNC is far easier on a phone.

## 6. If something fails

- **Browser says the proxy refused the connection.** ConnectBot is not
  connected, the forward was not created, or the port differs between
  ConnectBot and the browser.
- **The tunnel drops when the screen turns off.** Set ConnectBot's battery
  usage to Unrestricted, and keep **Stay connected** on.
- **ConnectBot reports "administratively prohibited".** The server's SSH
  daemon has `AllowTcpForwarding` switched off in `/etc/ssh/sshd_config`. Only
  the server administrator can change that.
- **ConnectBot cannot reach the server.** GlobalProtect has disconnected.
  Reconnect the VPN first, then reconnect in ConnectBot.
