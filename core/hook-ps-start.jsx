// ZiYouAutoLink - Photoshop "Start Application" hook.
// Registered once via app.notifiers (see install.ps1); Photoshop runs this file
// every time it starts. Paths come from the environment so this file stays ASCII.
(function () {
    try {
        var base = $.getenv("LOCALAPPDATA").replace(/\\/g, "/") + "/ZiYouAutoLink";
        var f = new File(base + "/ziyou-launch.vbs");
        if (f.exists) { f.execute(); }
    } catch (e) {
    }
})();
