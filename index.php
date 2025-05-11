<!doctype html>
<html lang="en">
<head>
    <?php
        $title = "Home";
        include("head.php");
    ?>
    <!-- Font Awesome CDN for icons -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.2/css/all.min.css">
    <!-- Favicon -->
    <link rel="icon" type="image/x-icon" href="icon.ico">
    <link rel="shortcut icon" type="image/x-icon" href="icon.ico">
    <style>
    body {
        background-image: url('https://raw.githubusercontent.com/faiz007t/libernetmod/main/re.jpg');
        background-size: cover;
        background-repeat: no-repeat;
        background-position: center center;
        background-attachment: fixed;
        height: 100%;
        min-height: 100vh;
    }
    html {
        height: 100%;
    }
    #ping-icon {
        position: relative;
    }
    .ping-heartbeat {
        position: absolute;
        left: 0; top: 0;
        width: 1em; height: 1em;
        border-radius: 50%;
        background: #17a2b8;
        opacity: 0.6;
        z-index: -1;
        animation: ping-anim 1s cubic-bezier(0, 0, 0.2, 1) infinite;
        display: none;
    }
    @keyframes ping-anim {
        0% { transform: scale(1); opacity: 0.6; }
        80% { transform: scale(2); opacity: 0; }
        100% { transform: scale(2); opacity: 0; }
    }
    </style>
</head>
<body>
<div id="app">
    <?php include('navbar.php'); ?>
    <div class="container-fluid" >
        <div class="row py-2">
            <div class="col-lg-8 col-md-9 mx-auto mt-3">
                <div class="card">
                    <div class="card-header">
                        <div class="text-center">
                            <h4><i class="fa fa-home"></i> Libernet Mod</h4>
                        </div>
                    </div>
                    <div class="card-body">
                        <div class="card-body py-0 px-0">
						<form>
                            <div class="form-group form-row my-auto">
                                <!-- ... your form fields ... -->
                            </div>
                        </form>
                            <div class="row">
                                <!-- ... other options ... -->
                                <!-- Status Section: ICON IS NOW DISTINCT AND DYNAMIC -->
                                <div class="col-lg-6 col-md-6">
                                    <i id="status-icon" class="fa fa-circle text-primary" style="margin-right: 4px;"></i>
                                    <span class="text-primary">Status: </span>
                                    <span id="status-text" class="text-primary">Disconnected</span>
                                    <span id="connected-time" class="text-primary" style="display:none;"></span>
                                </div>
                                <!-- WAN Info Section (HTML + JS) -->
                                <div class="col-lg-6 col-md-6">
									<i class="fa fa-server"></i>
                                    <span class="text-primary">IP: <span id="wan-ip">Loading...</span></span>
                                </div>
                                <!-- Ping Section -->
                                <div class="col-lg-6 col-md-6 pb-lg-1 d-flex align-items-center">
                                    <i class="fa fa-signal" id="ping-icon" style="margin-right: 6px; position: relative;">
                                        <span class="ping-heartbeat" id="ping-heartbeat"></span>
                                    </i>
                                    <span class="text-primary">Ping: <span id="wan-ping">...</span> ms</span>
                                </div>
								<div class="col-lg-6 col-md-6 pb-lg-1">
								    <i class="fa fa-flag"></i>
                                    <span class="text-primary">ISP: <span id="wan-net">Loading...</span> (<span id="wan-country">Loading...</span>)</span>
                                </div>
                                <!-- End WAN Info Section -->
				<div class="col-12 mb-2">
                                    <button type="button" class="btn btn-sm btn-outline-info" id="refresh-wan-btn">
                                        <i class="fa fa-refresh"></i> Refresh Info
                                    </button>
                                </div>
                                <div class="col pt-2">
                                    <pre ref="log" v-html="log" class="form-control text-left" style="height: auto; width: auto; font-size:80%; background-image-position: center; background-color: #444b8a "></pre>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <?php include('footer.php'); ?>
    </div>
</div>
<?php include("javascript.php"); ?>
<script src="js/index.js"></script>

<!-- WAN Info JavaScript (Dual Provider, with fallback) and Ping -->
<script>
// ---- STATUS ICON LOGIC ----
/**
 * connection:
 * 0 = Disconnected (blue)
 * 1 = Connecting (yellow)
 * 2 = Connected (green)
 * 3 = Info (cyan)
 */
function updateStatus(connection, connectedTime = "") {
    var icon = document.getElementById('status-icon');
    var text = document.getElementById('status-text');
    var time = document.getElementById('connected-time');
    // Remove all icon classes and color classes
    icon.className = 'fa';
    // Set icon and color
    switch(connection) {
        case 0: // Disconnected
            icon.classList.add('fa-circle', 'text-primary');
            text.className = 'text-primary';
            text.textContent = "Disconnected";
            time.style.display = 'none';
            break;
        case 1: // Connecting
            icon.classList.add('fa-exclamation-circle', 'text-warning');
            text.className = 'text-warning';
            text.textContent = "Connecting";
            time.style.display = 'none';
            break;
        case 2: // Connected
            icon.classList.add('fa-check-circle', 'text-success');
            text.className = 'text-success';
            text.textContent = "Connected";
            if (connectedTime) {
                time.textContent = connectedTime;
                time.style.display = '';
            } else {
                time.style.display = 'none';
            }
            break;
        case 3: // Info
            icon.classList.add('fa-info-circle', 'text-info');
            text.className = 'text-info';
            text.textContent = "Info";
            time.style.display = 'none';
            break;
        default:
            icon.classList.add('fa-circle', 'text-secondary');
            text.className = 'text-secondary';
            text.textContent = "Unknown";
            time.style.display = 'none';
            break;
    }
}

// Example: simulate status changes (remove in production)
document.addEventListener('DOMContentLoaded', function() {
    let conn = 0;
    let connectedSince = "";
    setInterval(function() {
        if (conn === 2) {
            // Show connected time for demo
            connectedSince = new Date().toLocaleTimeString();
            updateStatus(conn, connectedSince);
        } else {
            updateStatus(conn);
        }
        conn = (conn + 1) % 4;
    }, 3000);
});

// ---- WAN INFO + PING LOGIC (unchanged) ----
async function fetchWanInfo() {
    const ipElem = document.getElementById('wan-ip');
    const netElem = document.getElementById('wan-net');
    const countryElem = document.getElementById('wan-country');
    const btn = document.getElementById('refresh-wan-btn');
    const setFields = (ip, isp, country) => {
        ipElem.textContent = ip || 'Unavailable';
        netElem.textContent = isp || 'Unavailable';
        countryElem.textContent = country || 'Unavailable';
    };
    if (btn) btn.disabled = true;
    setFields('Loading...', 'Loading...', 'Loading...');
    try {
        const resp1 = await fetch('http://ip-api.com/json/');
        if (!resp1.ok) throw new Error('ip-api.com unavailable');
        const data1 = await resp1.json();
        if (data1.status === 'success') {
            setFields(data1.query, data1.isp, data1.country);
            if (btn) btn.disabled = false;
            return;
        }
    } catch (e) {}
    try {
        const resp2 = await fetch('https://api.ipapi.is/?q=');
        if (!resp2.ok) throw new Error('ipapi.is unavailable');
        const data2 = await resp2.json();
        setFields(
            data2.ip,
            data2.company && data2.company.name ? data2.company.name : 'Unavailable',
            data2.location && data2.location.country ? data2.location.country : 'Unavailable'
        );
    } catch (e) {
        setFields('Unavailable', 'Unavailable', 'Unavailable');
    } finally {
        if (btn) btn.disabled = false;
    }
}

// Browser-based "ping" using image load time
let pingTimeoutCount = 0;
function showPingHeartbeat(active) {
    const heartbeat = document.getElementById('ping-heartbeat');
    if (heartbeat) heartbeat.style.display = active ? 'block' : 'none';
}
function updatePing() {
    var pingElem = document.getElementById('wan-ping');
    showPingHeartbeat(true);
    pingElem.textContent = "...";
    var start = Date.now();
    var img = new window.Image();
    var finished = false;
    img.onload = img.onerror = function() {
        if (finished) return;
        finished = true;
        showPingHeartbeat(false);
        var latency = Date.now() - start;
        if (latency < 5000) {
            pingTimeoutCount = 0;
            pingElem.textContent = latency;
        } else {
            pingTimeoutCount++;
            pingElem.textContent = pingTimeoutCount > 3 ? "Unavailable" : "Timeout";
        }
    };
    img.src = "https://upload.wikimedia.org/wikipedia/commons/4/47/PNG_transparency_demonstration_1.png?cachebust=" + Math.random();
    setTimeout(function() {
        if (!finished) {
            finished = true;
            showPingHeartbeat(false);
            pingTimeoutCount++;
            pingElem.textContent = pingTimeoutCount > 3 ? "Unavailable" : "Timeout";
        }
    }, 5000);
}

document.addEventListener('DOMContentLoaded', function() {
    fetchWanInfo();
    updatePing();
    var btn = document.getElementById('refresh-wan-btn');
    if (btn) btn.addEventListener('click', function(e) {
        e.preventDefault();
        fetchWanInfo();
        updatePing();
    });
    setInterval(fetchWanInfo, 180000); // Refresh IP and ISP every 3 minutes
    setInterval(updatePing, 5000);     // Refresh ping every 5 seconds
});
</script>
</body>
</html>
