# Browse through the server from your PC (MobaXterm tunnel + Chrome)

MobaXterm opens an SSH tunnel to the server and offers a SOCKS proxy on your
PC at `127.0.0.1:1080`. Chrome, started by the script in this folder, sends all
its traffic into that proxy. Every page is then fetched by the server, so any
web page the server can reach, Chrome on your PC can reach too. Pages render
locally, so it is as fast as normal browsing.

GlobalProtect stays exactly as it is, and nothing has to be installed on the
server.

Files in this folder:

| File | Purpose |
| --- | --- |
| `chrome-via-server.cmd` | Starts Chrome through the tunnel. Copy it to your Desktop. |
| `README.md` | This guide. |

## 1. One-time setup in MobaXterm

1. Connect GlobalProtect as usual and start MobaXterm.
2. Open the menu **Tools**, then **MobaSSHTunnel (port forwarding)**.
3. Click **New SSH tunnel**.
4. At the top of the dialog choose **Dynamic port forwarding (SOCKS proxy)**.
5. Left box, *My computer with MobaXterm*: **Forwarded port** = `1080`.
6. Right box, *SSH server*:
   **SSH server address** = the server you normally log in to,
   **SSH login** = your user name on it,
   **SSH port** = `22` (unless your session uses another port).
7. Click **Save** and give the tunnel a name, for example `SOCKS via server`.
8. On the tunnel's row in the list: the key icon lets you choose a private key
   if you log in with one, and the settings icon lets you enable automatic
   start when MobaXterm opens and automatic reconnection.
9. Click the **play** button of the tunnel and enter your password when asked.
   The row then shows that the tunnel is running.

The proxy exists only while this tunnel is running, so MobaXterm has to stay
open. Stop it with the stop button of the same row.

## 2. Starting Chrome through the tunnel

Double-click `chrome-via-server.cmd`. It starts Chrome with:

- the SOCKS proxy at `127.0.0.1:1080`;
- name lookup done by the server, so internal host names work the same way as
  they do on the server;
- a separate Chrome profile called `ChromeViaServer`. Your normal Chrome is
  untouched, and the proxy settings always apply, even when your normal Chrome
  is already open. (Chrome ignores proxy options when the same profile is
  already running, so this separation is what makes it reliable.)

The first tab shows the address the web sees you from. Through the tunnel it
should be the server's address. The definitive test is a page that opens on the
server but not on your PC.

To open a page directly:

```
chrome-via-server.cmd https://some.internal.host/
```

If you would rather keep the bookmarks and logins of your normal Chrome
profile, install a proxy-switching extension such as FoxyProxy, add a SOCKS5
proxy `127.0.0.1` port `1080`, and switch it on only when you need it.

## 3. Firefox instead of Chrome

Open Settings, search for "proxy", click **Settings...**, choose
**Manual proxy configuration**: SOCKS Host `127.0.0.1`, Port `1080`,
**SOCKS v5**, and tick **Proxy DNS when using SOCKS v5**. Choose
**No proxy** to go back to normal browsing.

## 4. The same tunnel without MobaSSHTunnel

Any SSH client can create the proxy. In a MobaXterm local terminal, or in a
Windows command prompt (Windows 10 and 11 ship with `ssh`):

```
ssh -N -D 1080 USERNAME@SERVER
```

Keep that window open. Closing it stops the tunnel.

## 5. If something fails

- **Chrome shows "proxy server is refusing connections" or
  ERR_PROXY_CONNECTION_FAILED.** The tunnel is not running, or it listens on a
  different port. Check the play button and that both sides use `1080`.
- **The tunnel is up but no page loads, or the tunnel log says
  "administratively prohibited".** The server's SSH daemon has
  `AllowTcpForwarding` switched off in `/etc/ssh/sshd_config`. Only the server
  administrator can change that.
- **Port 1080 is already in use on your PC.** Pick another port, for example
  `1081`, both in MobaSSHTunnel and in the `SOCKS_PORT` line of the script.
- **Everything stops after the VPN drops or the laptop sleeps.** Press the play
  button again, or enable automatic reconnection in the tunnel's settings.
