<!DOCTYPE html>
<html lang="en">
<head>
  <title>Libernet Mod</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <!-- Bootstrap & FontAwesome CDN -->
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.0/css/all.min.css">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/bootstrap/5.3.3/css/bootstrap.min.css">
  <style>
    html, body {
      height: 100%;
      margin: 0;
      padding: 0;
      background: #222;
      color: #fff;
      touch-action: manipulation;
    }
    #app {
      min-height: 100vh;
      padding-top: 60px;
      padding-bottom: 20px;
    }
    .container-fluid {
      max-width: 100vw;
    }
    .card {
      background: rgba(30, 30, 40, 0.98);
      color: #fff;
      border: 1px solid #444;
      box-shadow: 0 2px 8px #0004;
    }
    .card-header {
      background: rgba(20, 20, 30, 0.98);
      border-bottom: 1px solid #444;
    }
    .form-control, .form-select {
      background-color: #2a2a3a;
      color: #fff;
      border: 1px solid #555;
    }
    .form-control:disabled, .form-select:disabled {
      background-color: #2a2a3a;
      opacity: 0.7;
    }
    pre {
      background: #23234a !important;
      color: #0f0;
      font-size: 80%;
      padding: 12px;
      border-radius: 8px;
      margin-bottom: 0;
      min-height: 80px;
    }
    #luci-back {
      position: fixed;
      top: 10px;
      left: 10px;
      z-index: 1000;
      background: rgba(0,0,0,0.7);
      border: none;
      border-radius: 50%;
      padding: 8px;
      width: 48px;
      height: 48px;
      cursor: pointer;
      transition: all 0.2s;
      touch-action: manipulation;
      box-shadow: 0 2px 8px #0006;
    }
    #luci-back svg {
      width: 28px;
      height: 28px;
      fill: white;
    }
    @media (max-width: 768px) {
      #luci-back {
        width: 44px;
        height: 44px;
        top: 8px;
        left: 8px;
      }
      #luci-back svg {
        width: 24px;
        height: 24px;
      }
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
  <!-- LuCI Back Button -->
  <button id="luci-back"
    role="button"
    aria-label="Return to LuCI interface"
    onclick="window.location.href='/cgi-bin/luci/'">
    <svg viewBox="0 0 24 24"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/></svg>
  </button>

  <div id="app">
    <div class="container-fluid">
      <div class="row py-2">
        <div class="col-lg-8 col-md-10 mx-auto mt-3">
          <div class="card">
            <div class="card-header">
              <div class="text-center">
                <h4><i class="fa fa-home"></i> Libernet Mod</h4>
              </div>
            </div>
            <div class="card-body">
              <form @submit.prevent="runLibernet">
                <div class="form-group row align-items-center">
                  <div class="col-md-4 mb-2">
                    <label class="form-label mb-1">Mode</label>
                    <select class="form-select" v-model.number="config.mode" :disabled="status" required>
                      <option v-for="mode in config.temp.modes" :value="mode.value">{{ mode.name }}</option>
                    </select>
                  </div>
                  <div class="col-md-4 mb-2">
                    <label class="form-label mb-1">Config</label>
                    <select class="form-select" v-model="config.profile" :disabled="status" required>
                      <option v-for="profile in config.profiles" :value="profile">{{ profile }}</option>
                    </select>
                  </div>
                  <div class="col-md-4 mb-2 d-flex align-items-end">
                    <button type="submit" class="btn w-100" :class="{ 'btn-danger': status, 'btn-primary': !status }">{{ statusText }}</button>
                  </div>
                </div>
              </form>
              <div class="row mt-2">
                <div v-if="config.mode !== 5" class="col-md-6 mb-2">
                  <div class="form-check form-switch">
                    <input class="form-check-input" type="checkbox" v-model="config.system.tun2socks.legacy" :disabled="status" id="tun2socks-legacy">
                    <label class="form-check-label" for="tun2socks-legacy">Use tun2socks legacy</label>
                  </div>
                </div>
                <div class="col-md-6 mb-2">
                  <div class="form-check">
                    <input class="form-check-input" type="checkbox" v-model="config.system.tunnel.autostart" :disabled="status" id="autostart">
                    <label class="form-check-label" for="autostart">Auto start Libernet on boot</label>
                  </div>
                </div>
                <div class="col-md-6 mb-2">
                  <div class="form-check">
                    <input class="form-check-input" type="checkbox" v-model="config.system.tunnel.dns_resolver" :disabled="status" id="dns-resolver">
                    <label class="form-check-label" for="dns-resolver">DNS resolver</label>
                  </div>
                </div>
                <div class="col-md-6 mb-2">
                  <div class="form-check">
                    <input class="form-check-input" type="checkbox" v-model="config.system.system.memory_cleaner" :disabled="status" id="memory-cleaner">
                    <label class="form-check-label" for="memory-cleaner">Memory cleaner</label>
                  </div>
                </div>
                <div class="col-md-12 mb-2">
                  <div class="form-check">
                    <input class="form-check-input" type="checkbox" v-model="config.system.tunnel.ping_loop" :disabled="status" id="ping-loop">
                    <label class="form-check-label" for="ping-loop">PING loop</label>
                  </div>
                </div>
                <div class="col-md-6 mb-2">
                  <i class="fa fa-flag"></i>
                  <span class="text-primary">Status: </span>
                  <span :class="{
                    'text-primary': connection === 0,
                    'text-warning': connection === 1,
                    'text-success': connection === 2,
                    'text-info': connection === 3
                  }">{{ connectionText }}</span>
                  <span v-if="connection === 2" class="text-primary">{{ connectedTime }}</span>
                </div>
                <div class="col-md-6 mb-2">
                  <i class="fa fa-server"></i>
                  <span class="text-primary">IP: <span id="wan-ip"></span></span>
                </div>
                <div class="col-md-6 mb-2 d-flex align-items-center">
                  <i class="fa fa-signal" id="ping-icon" style="margin-right: 6px; position: relative;">
                    <span class="ping-heartbeat" id="ping-heartbeat"></span>
                  </i>
                  <span class="text-primary">Ping: <span id="wan-ping"></span> ms</span>
                </div>
                <div class="col-md-6 mb-2">
                  <i class="fa fa-flag-o"></i>
                  <span class="text-primary">ISP: <span id="wan-net"></span> (<span id="wan-country"></span>)</span>
                </div>
                <div class="col-12 mb-2">
                  <button class="btn btn-sm btn-outline-info" id="refresh-wan-btn" type="button">
                    <i class="fa fa-refresh"></i> Refresh Info
                  </button>
                </div>
                <div class="col-12 pt-2">
                  <pre ref="log" v-html="log"></pre>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>

  // WAN Info and Ping Logic
  async function fetchWithTimeout(resource, options = {}) {
    const controller = new AbortController();
    const id = setTimeout(() => controller.abort(), 5000);
    options.signal = controller.signal;
    try {
      const response = await fetch(resource, options);
      clearTimeout(id);
      return response;
    } catch (e) {
      clearTimeout(id);
      throw e;
    }
  }

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
      try {
        const resp1 = await fetchWithTimeout('https://ip-api.com/json/');
        if (!resp1.ok) throw new Error('ip-api.com unavailable');
        const data1 = await resp1.json();
        if (data1.status === 'success') {
          setFields(data1.query, data1.isp, data1.country);
          return;
        }
      } catch (e) {}
      try {
        const resp2 = await fetchWithTimeout('https://api.ipapi.is/?q=');
        if (!resp2.ok) throw new Error('ipapi.is unavailable');
        const data2 = await resp2.json();
        setFields(
          data2.ip,
          data2.company && data2.company.name ? data2.company.name : 'Unavailable',
          data2.location && data2.location.country ? data2.location.country : 'Unavailable'
        );
      } catch (e) {
        setFields('Unavailable', 'Unavailable', 'Unavailable');
      }
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
    const btn = document.getElementById('refresh-wan-btn');
    if (btn) {
      btn.addEventListener('click', function(e) {
        e.preventDefault();
        fetchWanInfo();
        updatePing();
      });
      // Auto-click refresh every 5 seconds
      setInterval(() => {
        btn.click();
      }, 5000);
    }
  });
  </script>
</body>
</html>
