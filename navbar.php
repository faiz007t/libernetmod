<?php
    $url_array = explode('/', $_SERVER['REQUEST_URI']);
    $url = end($url_array);
?>
<!-- Font Awesome CDN -->
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.2/css/all.min.css">
<style>
    body { margin: 0; padding-top: 60px; font-family: Arial, sans-serif; }
    .fixed-menu {
        position: fixed;
        top: 0; left: 0; width: 100%;
        background: #11195b; margin: 0; padding: 0;
        list-style: none; display: flex; z-index: 1030;
        box-shadow: 0 2px 8px rgba(0,0,0,0.08);
    }
    /* Cyan bar below menu */
    .fixed-menu::after {
        content: "";
        display: block;
        position: absolute;
        left: 0; right: 0; bottom: -4px;
        height: 4px;
        background: #00ffff; /* Cyan */
        z-index: 1031;
    }
    .fixed-menu li { margin: 0; }
    .fixed-menu a {
        display: block; color: #fff !important; padding: 16px 24px;
        text-decoration: none; font-size: 16px; transition: background 0.2s;
    }
    .fixed-menu a.active, .fixed-menu a:hover {
        background: #222b7b;
        color: #fff !important;
    }
    @media (max-width: 600px) {
        .fixed-menu a { padding: 14px 12px; font-size: 15px; }
        .fixed-menu::after { height: 3px; bottom: -3px; }
    }
</style>
<ul class="fixed-menu"><li><a href="index.php"<?php if ($url === 'index.php') echo ' class="active"'; ?>><i class="fa fa-home"></i> Home</a></li><li><a href="config.php"<?php if ($url === 'config.php') echo ' class="active"'; ?>><i class="fa fa-gear"></i> Configuration</a></li><li><a href="about.php"<?php if ($url === 'about.php') echo ' class="active"'; ?>><i class="fa fa-info"></i> About</a></li></ul>
