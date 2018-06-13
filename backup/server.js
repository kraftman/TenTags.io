

var bb = require('./bb')
var filesTobackup = [
  {fileName: 'redis-general.rdb', filePath: '/data/general/dump.rdb'},
  {fileName: 'redis-user.rdb', filePath: '/data/comment/dump.rdb'},
  {fileName: 'redis-comment.rdb', filePath: '/data/user/dump.rdb'},
]

filesTobackup.forEach(function(item) {

  var newBB = new bb(item)
  //newBB.Run()
})

function myFunc(err, result) {
  if(err) {
    console.log('error: ' + err)
  }
}
