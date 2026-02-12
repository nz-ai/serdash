"""Collect system metrics (Linux and macOS)."""

import json
import platform
import subprocess
from pathlib import Path
from datetime import datetime


def collect() -> dict:
    """Collect metrics for current platform."""
    data = {
        "sampled_at": datetime.utcnow().isoformat() + "Z",
        "hostname": _hostname(),
        "platform": platform.system(),
    }

    if platform.system() == "Linux":
        data.update(_collect_linux())
    elif platform.system() == "Darwin":
        data.update(_collect_macos())
    else:
        data["disk"] = _collect_disk_generic()
        data["memory"] = {}
        data["cpu"] = {}
        data["network_interfaces"] = []
        data["listening_ports"] = []
        data["connections"] = []

    return data


def _hostname() -> str:
    import socket
    return socket.gethostname()


def _collect_linux() -> dict:
    out = {}

    # Disk (use mock mounts in dev when SERDASH_DEV_DISK_MOUNTS is set)
    dev_mounts = _get_dev_disk_mounts()
    out["disk"] = _collect_disk_linux_mock(dev_mounts) if dev_mounts else _collect_disk_linux()

    # Memory from /proc/meminfo
    out["memory"] = _collect_memory_linux()

    # CPU from /proc/loadavg and /proc/stat
    out["cpu"] = _collect_cpu_linux()

    # Network
    out["network_interfaces"] = _collect_network_linux()
    out["listening_ports"] = _collect_listening_linux()
    out["connections"] = _collect_connections_linux()

    return out


def _get_dev_disk_mounts() -> list:
    """Return list of mount points for dev mock, or empty if not configured."""
    import os
    val = os.environ.get("SERDASH_DEV_DISK_MOUNTS", "").strip()
    if not val:
        return []
    return [m.strip() for m in val.split(",") if m.strip()]


def _collect_disk_linux_mock(mounts: list) -> list:
    """Return mock disk data for dev (SERDASH_DEV_DISK_MOUNTS)."""
    # Realistic sizes: / = 128GB, /media = 2TB, /opt/backup = 4TB
    sizes = {
        "/": 128 * 1024**3,
        "/media": 2 * 1024**4,
        "/opt/backup": 4 * 1024**4,
    }
    out = []
    for mp in mounts:
        total = sizes.get(mp, 256 * 1024**3)
        # Use ~70–85% full for variety
        pct_used = 0.70 + (abs(hash(mp)) % 16) / 100.0
        used = int(total * pct_used)
        free = total - used
        out.append({
            "mount_point": mp,
            "total_bytes": total,
            "free_bytes": free,
        })
    return out


def _collect_disk_linux() -> list:
    try:
        r = subprocess.run(
            ["df", "-B1", "--output=source,fstype,target,size,avail"],
            capture_output=True, text=True, timeout=10
        )
        if r.returncode != 0:
            return []
        lines = r.stdout.strip().split("\n")[1:]  # skip header
        mounts = []
        for line in lines:
            parts = line.split()
            if len(parts) >= 5:
                mount_point = parts[2]
                total = int(parts[3]) if parts[3].isdigit() else None
                avail = int(parts[4]) if parts[4].isdigit() else None
                # Skip tiny or pseudo filesystems
                if mount_point.startswith("/") and total and total > 100_000_000:
                    mounts.append({
                        "mount_point": mount_point,
                        "total_bytes": total,
                        "free_bytes": avail,
                    })
        return mounts
    except Exception:
        return []


def _collect_disk_generic() -> list:
    try:
        r = subprocess.run(
            ["df", "-k"],
            capture_output=True, text=True, timeout=10
        )
        if r.returncode != 0:
            return []
        # Parse df output - simplified
        return []
    except Exception:
        return []


def _collect_memory_linux() -> dict:
    mem = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if ":" in line:
                    k, v = line.split(":", 1)
                    k = k.strip()
                    v = int(v.strip().split()[0]) * 1024  # kB to bytes
                    if k == "MemTotal":
                        mem["total_bytes"] = v
                    elif k == "MemFree":
                        mem["free_bytes"] = v
                    elif k == "MemAvailable":
                        mem["available_bytes"] = v
        if "total_bytes" in mem and "available_bytes" in mem:
            mem["used_bytes"] = mem["total_bytes"] - mem["available_bytes"]
        elif "total_bytes" in mem and "free_bytes" in mem:
            mem["used_bytes"] = mem["total_bytes"] - mem["free_bytes"]
        return mem
    except Exception:
        return {}


def _collect_cpu_linux() -> dict:
    cpu = {}
    try:
        with open("/proc/loadavg") as f:
            load = f.read().strip().split()[:3]
            cpu["load_1m"], cpu["load_5m"], cpu["load_15m"] = map(float, load)
    except Exception:
        pass

    # Temperature
    try:
        temps = []
        for p in Path("/sys/class/thermal").glob("thermal_zone*/temp"):
            try:
                t = int(p.read_text().strip())
                if t > 0:
                    temps.append(t / 1000.0)  # millidegrees to celsius
            except (OSError, ValueError):
                pass
        if temps:
            cpu["temperature_celsius"] = max(temps)
    except Exception:
        pass

    # Usage from /proc/stat (simplified - would need two samples for %)
    try:
        with open("/proc/stat") as f:
            for line in f:
                if line.startswith("cpu "):
                    parts = line.split()
                    total = sum(int(x) for x in parts[1:])
                    idle = int(parts[4])
                    if total > 0:
                        cpu["usage_percent"] = round(100.0 * (1 - idle / total), 2)
                    break
    except Exception:
        pass

    return cpu


def _collect_network_linux() -> list:
    ifaces = []
    try:
        r = subprocess.run(
            ["ip", "-j", "addr"],
            capture_output=True, text=True, timeout=5
        )
        if r.returncode != 0:
            return []
        data = json.loads(r.stdout)
        for iface in data:
            name = iface.get("ifname", "")
            state = iface.get("operstate", "unknown")
            addrs = []
            for addr in iface.get("addr_info", []):
                a = addr.get("local")
                if a:
                    addrs.append(a)
            ifaces.append({
                "interface": name,
                "status": state,
                "ip_addresses": addrs,
            })
    except Exception:
        pass
    return ifaces


def _collect_listening_linux() -> list:
    ports = []
    try:
        r = subprocess.run(
            ["ss", "-tuln"],
            capture_output=True, text=True, timeout=5
        )
        if r.returncode != 0:
            return []
        for line in r.stdout.strip().split("\n")[1:]:
            parts = line.split()
            if len(parts) >= 5:
                # Netid State Recv-Q Send-Q Local:Port Peer:Port
                local = parts[4]
                if ":" in local:
                    port = local.split(":")[-1]
                    try:
                        ports.append({
                            "protocol": "tcp",
                            "port": int(port),
                            "process": None,
                        })
                    except ValueError:
                        pass
    except Exception:
        pass
    return ports


def _collect_connections_linux() -> list:
    conns = []
    try:
        r = subprocess.run(
            ["ss", "-tun"],
            capture_output=True, text=True, timeout=5
        )
        if r.returncode != 0:
            return []
        for line in r.stdout.strip().split("\n")[1:]:
            parts = line.split()
            if len(parts) >= 5:
                local, remote = parts[4], parts[5]
                conns.append({
                    "local_addr": local,
                    "remote_addr": remote,
                    "state": parts[0] if parts else None,
                })
    except Exception:
        pass
    return conns


def _collect_macos() -> dict:
    out = {}
    out["disk"] = _collect_disk_macos()
    out["memory"] = _collect_memory_macos()
    out["cpu"] = _collect_cpu_macos()
    out["network_interfaces"] = _collect_network_macos()
    out["listening_ports"] = _collect_listening_macos()
    out["connections"] = _collect_connections_macos()
    return out


def _collect_disk_macos() -> list:
    mounts = []
    try:
        r = subprocess.run(
            ["df", "-k"],
            capture_output=True, text=True, timeout=10
        )
        for line in r.stdout.strip().split("\n")[1:]:
            parts = line.split()
            if len(parts) >= 6:
                mount = parts[-1]
                total_k = int(parts[1]) * 1024
                avail_k = int(parts[3]) * 1024
                if mount.startswith("/") and total_k > 100_000_000:
                    mounts.append({
                        "mount_point": mount,
                        "total_bytes": total_k,
                        "free_bytes": avail_k,
                    })
    except Exception:
        pass
    return mounts


def _collect_memory_macos() -> dict:
    mem = {}
    try:
        r = subprocess.run(
            ["vm_stat"],
            capture_output=True, text=True, timeout=5
        )
        page_size = 4096
        for line in r.stdout.strip().split("\n"):
            if ":" in line:
                k, v = line.split(":", 1)
                v = int(v.strip().rstrip(".")) * page_size
                if "Pages free" in k:
                    mem["free_bytes"] = v
                elif "Pages active" in k:
                    mem["active_bytes"] = v
                elif "Pages inactive" in k:
                    mem["inactive_bytes"] = v
                elif "Pages wired" in k:
                    mem["wired_bytes"] = v
        # Approximate total/used
        sysctl = subprocess.run(
            ["sysctl", "-n", "hw.memsize"],
            capture_output=True, text=True, timeout=2
        )
        if sysctl.returncode == 0:
            mem["total_bytes"] = int(sysctl.stdout.strip())
            if "free_bytes" in mem:
                mem["used_bytes"] = mem["total_bytes"] - mem["free_bytes"]
    except Exception:
        pass
    return mem


def _collect_cpu_macos() -> dict:
    cpu = {}
    try:
        r = subprocess.run(
            ["sysctl", "-n", "machdep.cpu.brand_string"],
            capture_output=True, text=True, timeout=2
        )
        if r.returncode == 0:
            cpu["brand"] = r.stdout.strip()
    except Exception:
        pass
    return cpu


def _collect_network_macos() -> list:
    ifaces = []
    try:
        r = subprocess.run(
            ["ifconfig"],
            capture_output=True, text=True, timeout=5
        )
        current = None
        for line in r.stdout.split("\n"):
            if not line.startswith("\t") and ":" in line:
                current = {"interface": line.split(":")[0], "status": "unknown", "ip_addresses": []}
                ifaces.append(current)
            elif current and "inet " in line:
                parts = line.split()
                for i, p in enumerate(parts):
                    if p == "inet" and i + 1 < len(parts):
                        current["ip_addresses"].append(parts[i + 1])
                        break
    except Exception:
        pass
    return ifaces


def _collect_listening_macos() -> list:
    ports = []
    try:
        r = subprocess.run(
            ["netstat", "-an"],
            capture_output=True, text=True, timeout=5
        )
        for line in r.stdout.split("\n"):
            if "LISTEN" in line and ". " in line:
                parts = line.split()
                for p in parts:
                    if "." in p and p.count(".") == 3:
                        port = p.split(".")[-1]
                        try:
                            ports.append({"protocol": "tcp", "port": int(port), "process": None})
                        except ValueError:
                            pass
                        break
    except Exception:
        pass
    return ports


def _collect_connections_macos() -> list:
    return []  # Simplified for now
