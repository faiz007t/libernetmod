<?php
    $url_array = explode('/', $_SERVER['REQUEST_URI']);
    $url = end($url_array);
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Libernet Mod</title>
    <!-- Bootstrap CSS (v4.6 or v5 recommended) -->
    <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css">
    <!-- Font Awesome for icons (optional) -->
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <style>
    .navbar-toggler {
        border-color: rgba(255,255,255,0.5);
    }
    .navbar-toggler-icon {
        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 30 30'%3E%3Cpath stroke='rgba(255,255,255,1)' stroke-width='2' stroke-linecap='round' stroke-miterlimit='10' d='M4 7h22M4 15h22M4 23h22'/%3E%3C/svg%3E");
    }
    </style>
</head>
<body>
<nav class="navbar navbar-expand-lg navbar-dark" style="background-color: #11195b;">
    <a class="navbar-brand" href="#"></a>
    <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarNavDropdown" aria-controls="navbarNavDropdown" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
    </button>
    <div class="collapse navbar-collapse justify-content-center" id="navbarNavDropdown">
        <ul class="navbar-nav">
            <li class="nav-item <?php if ($url === 'index.php') echo 'active'; ?>">
                <a class="nav-link text-white" href="index.php">
                    <i class="fa fa-home"></i> Home
                    <?php if ($url === 'index.php') echo '<span class="sr-only">(current)</span>'; ?>
                </a>
            </li>
            <li class="nav-item <?php if ($url === 'config.php') echo 'active'; ?>">
                <a class="nav-link text-white" href="config.php">
                    <i class="fa fa-gear"></i> Configuration
                </a>
            </li>
            <li class="nav-item <?php if ($url === 'about.php') echo 'active'; ?>">
                <a class="nav-link text-white" href="about.php">
                    <i class="fa fa-info"></i> About
                </a>
            </li>
        </ul>
    </div>
</nav>

<!-- Bootstrap JS, Popper.js, and jQuery (for Bootstrap 4) -->
<script src="https://code.jquery.com/jquery-3.5.1.slim.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/popper.js@1.16.1/dist/umd/popper.min.js"></script>
<script src="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/js/bootstrap.min.js"></script>
</body>
</html>
