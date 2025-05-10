<?php
    $url_array =  explode('/', $_SERVER['REQUEST_URI']) ;
    $url = end($url_array);
?>
<!-- Add this style block in your <head> or in your CSS file -->
<style>
.navbar-toggler {
    border-color: rgba(255,255,255,0.5);
}
.navbar-toggler-icon {
    background-image: url("data:image/svg+xml;charset=utf8,%3Csvg viewBox='0 0 30 30' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath stroke='rgba%28255,255,255,1%29' stroke-width='2' stroke-linecap='round' stroke-miterlimit='10' d='M4 7h22M4 15h22M4 23h22'/%3E%3C/svg%3E");
}
</style>

<nav class="navbar navbar-expand-lg navbar-light" style="background-color: #11195b;">
    <a class="navbar-brand" href="#"></a>
    <button class="navbar-toggler" type="button" data-toggle="collapse" data-target="#navbarNavDropdown" aria-controls="navbarNavDropdown" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
    </button>
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
