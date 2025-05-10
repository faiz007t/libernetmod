<?php
    $url_array =  explode('/', $_SERVER['REQUEST_URI']) ;
    $url = end($url_array);
?>
<nav class="navbar navbar-expand-lg navbar-light" style="background-color: #11195b;">
    <div class="collapse navbar-collapse" id="navbarNavDropdown">
        <ul class="navbar-nav mr-auto">
            <li class="nav-item <?php if ($url === 'index.php') echo 'active'; ?>">
                <a class="nav-link" href="index.php"><i class="fa fa-home"></i> Home <span class="sr-only">(current)</span></a>
            </li>
            <li class="nav-item <?php if ($url === 'config.php') echo 'active'; ?>">
                <a class="nav-link" href="config.php"><i class="fa fa-gear"></i> Configuration</a>
            </li>
            <li class="nav-item <?php if ($url === 'about.php') echo 'active'; ?>">
                <a class="nav-link" href="about.php"><i class="fa fa-info"></i> About</a>
            </li>
        </ul>
    </div>
</nav>
