var page = require('webpage').create();
page.settings.userAgent = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/53.0.2756.0 Safari/537.36 OPR/40.0.2267.0 (Edition developer)';
page.open('http://imgur.com/kg1l1vJ', function(status) {
  console.log("Status: " + status);
  if (status !== 'success') {
    console.log('Unable to load the address!');
    phantom.exit();
  } else {
    window.setTimeout(function () {
      page.render('example.png');
      phantom.exit();
    }, 22000);
  }
});
