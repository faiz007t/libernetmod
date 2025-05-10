<!doctype html>
<html lang="en">
<head>
    <?php
        $title = "Home";
        include("head.php");
    ?>
    <!-- Favicon -->
    <link rel="icon" type="image/x-icon" href="icon.ico">
    <link rel="shortcut icon" type="image/x-icon" href="icon.ico">
    <style>
    body {
        background-image: url('img/re.jpg');
        background-size: cover;
        background-repeat: no-repeat;
        background-position: center center;
        background-attachment: fixed;
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
						<form @submit.prevent="runLibernet">
                            <div class="form-group form-row my-auto">
                                <div class="col-lg-4 col-md-4 form-row py-1">
                                    <div class="col-lg-4 col-md-3 my-auto">
                                        <label class="my-auto">Mode</label>
									</div>
                                    <div class="col">
                                        <select class="form-control" v-model.number="config.mode" :disabled="status === true" required>
                                            <option v-for="mode in config.temp.modes" :value="mode.value">{{ mode.name }}</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col-lg-4 col-md-4 form-row py-1">
                                    <div class="col-lg-4 col-md-3 my-auto">
                                        <label class="my-auto" >Config</label>
									</div>
                                    <div class="col">
                                        <select class="form-control " v-model="config.profile" :disabled="status === true" required>
                                            <option v-for="profile in config.profiles" :value="profile">{{ profile }}</option>
                                        </select>
                                    </div>
                                </div>
                                <div class="col form-row py-1">
                                    <div class="col">
                                       <button type="submit" class="btn" :class="{ 'btn-danger': status, 'btn-primary': !status }">{{ statusText }}</button>
                                    </div>
                                </div>
                            </div>
                        </form>
                            <div class="row">
                                <div v-if="config.mode !== 5" class="col-lg-6 col-md-6 pb-lg-1">
                                    <div class="form-check form-switch">
                                        <input class="form-check-input" type="checkbox" v-model="config.system.tun2socks.legacy" :disabled="status === true" id="tun2socks-legacy" >
                                        <label class="form-check-label" for="tun2socks-legacy">
                                            Use tun2socks legacy
                                        </label>
                                    </div>
                                </div>
                                <div class="col-lg-6 col-md-6 pb-lg-1">
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" v-model="config.system.tunnel.autostart" :disabled="status === true" id="autostart">
                                        <label class="form-check-label" for="autostart">
                                            Auto start Libernet on boot
                                        </label>
                                    </div>
                                </div>
                                <div class="col-lg-6 col-md-6 pb-lg-1">
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" v-model="config.system.tunnel.dns_resolver" :disabled="status === true" id="dns-resolver">
                                        <label class="form-check-label" for="dns-resolver">
                                            DNS resolver
                                        </label>
                                    </div>
                                </div>
                                <div class="col-lg-6 col-md-6 pb-lg-1">
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" v-model="config.system.system.memory_cleaner" :disabled="status === true" id="memory-cleaner">
                                        <label class="form-check-label" for="memory-cleaner">
                                            Memory cleaner
                                        </label>
                                    </div>
                                </div>
                                <div class="col-md-12 pb-lg-1">
                                    <div class="form-check">
                                        <input class="form-check-input" type="checkbox" v-model="config.system.tunnel.ping_loop" :disabled="status === true" id="ping-loop">
                                        <label class="form-check-label" for="ping-loop">
                                            PING loop
                                        </label>
                                    </div>
                                </div>
                                <div class="col-lg-6 col-md-6">
									<i class="fa fa-flag"></i>
                                    <span class="text-primary">Status: </span><span :class="{ 'text-primary': connection === 0, 'text-warning': connection === 1, 'text-success': connection === 2, 'text-info': connection === 3 }">{{ connectionText }}</span>
                                    <span v-if="connection === 2" class="text-primary">{{ connectedTime }}</span>
                                </div>
                                <!-- WAN Info Section (HTML + JS) -->
                                <div class="col-lg-6 col-md-6">
									<i class="fa fa-server"></i>
                                    <span class="text-primary">WAN IP: <span id="wan-ip">Loading...</span></span>
                                </div>
								<div class="col-lg-6 col-md-6 pb-lg-1">
								    <i class="fa fa-flag-o"></i>
                                    <span class="text-primary">ISP: <span id="wan-net">Loading...</span> | <span id="wan-country">Loading...</span></span>
                                </div>
                                <div v-if="connection === 2" class="col-lg-6 col-md-6" >
									<i class="fa fa-exchange"></i>
                                    <span class="text-primary">TX: </span><span class="text-primary">{{ total_data.tx }} | RX: {{ total_data.rx }}</span>
                                </div>
				<div class="col-12 mb-2">
                                    <button class="btn btn-sm btn-outline-info" id="refresh-wan-btn">
                                        <i class="fa fa-refresh"></i> Refresh WAN Info
                                    </button>
                                </div>
                                <!-- End WAN Info Section -->
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

<!-- WAN Info JavaScript (Dual Provider, with fallback) -->
<script>
async function fetchWanInfo() {
    const ipElem = document.getElementById('wan-ip');
    const netElem = document.getElementById('wan-net');
    const countryElem = document.getElementById('wan-country');
    const btn = document.getElementById('refresh-wan-btn');

    // Helper to set fields
    const setFields = (ip, isp, country) => {
        ipElem.textContent = ip || 'Unavailable';
        netElem.textContent = isp || 'Unavailable';
        countryElem.textContent = country || 'Unavailable';
    };

    // Loading state
    if (btn) btn.disabled = true;
    setFields('Loading...', 'Loading...', 'Loading...');

    // Try ip-api.com first
    try {
        const resp1 = await fetch('http://ip-api.com/json/');
        if (!resp1.ok) throw new Error('ip-api.com unavailable');
        const data1 = await resp1.json();
        if (data1.status === 'success') {
            setFields(data1.query, data1.isp, data1.country);
            if (btn) btn.disabled = false;
            return;
        }
    } catch (e) {
        // Continue to fallback
    }

    // Fallback: ipapi.is (no API key required)
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

document.addEventListener('DOMContentLoaded', function() {
    fetchWanInfo();
    var btn = document.getElementById('refresh-wan-btn');
    if (btn) btn.addEventListener('click', function(e) {
        e.preventDefault();
        fetchWanInfo();
    });
    // Optional: setInterval(fetchWanInfo, 300000); // Refresh every 5 minutes
});
</script>
</body>
</html>
