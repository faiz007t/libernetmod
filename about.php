<!doctype html>
<html lang="en">
<head>
    <?php
        $title = "About";
        include("head.php");
    ?>
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
    <div class="container">
        <div class="row">
            <div class="col-lg-8 col-md-12 mx-auto mt-4 mb-2">
                <div class="card">
                    <div class="card-header">
                        <div class="text-center">
                            <h3><i class="fa fa-info"></i> About Libernet Mod</h3>
                        </div>
                    </div>
                    <div class="card-body">
                        <div>
                            <p>
                                Libernet is open source web app for tunneling internet on OpenWRT with ease.
                            </p>
                            <span>Working features:</span>
                            <ul class="m-2">
                                <li>SSH with proxy</li>
                                <li>SSH-SSL</li>
                                <li>V2Ray VMess</li>
                                <li>V2Ray VLESS</li>
                                <li>V2Ray Trojan</li>
                                <li>Trojan</li>
                                <li>Shadowsocks</li>
                                <li>OpenVPN</li>
                            </ul>
                            <p>
                                Some features still under development!
                            </p>
                        </div>
                    </div>
                </div>
            </div>
        </div>
        <?php include('footer.php'); ?>
    </div>
</div>
<?php include("javascript.php"); ?>
<script src="js/about.js"></script>
</body>
</html>
