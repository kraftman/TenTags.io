var B2 = require('backblaze-b2');
var fs = require("fs");
var fileBuffer
var file = fs.readFile("Dockerfile", function (err, data) {
    if (err) throw err;
    fileBuffer = data
});

var b2 = new B2({
    accountId: 'a872155e29d7',
    applicationKey: '00198e928abe288f6ac863598106f2aaffd3d1d34e'
});
var bucketID = '7af8c7029115f53e52b90d17'

async function test() {
  try {
  var test = await b2.authorize();

  // var test2 = await b2.createBucket(
  //   bucketID,
  //   'allPrivate' // one of `allPublic`, `allPrivate`
  // );
  // console.log(test2)
  var uploadURL = await b2.getUploadUrl(bucketID)
  console.log('THIS ======')
  console.log(uploadURL.data)
  var done = await b2.uploadFile({
    uploadUrl: uploadURL.data.uploadUrl,

    uploadAuthToken: uploadURL.data.authorizationToken,
    filename: 'Dockerfile',
    mime: '', // optonal mime type, will default to 'b2/x-auto' if not provided
    data: fileBuffer, // this is expecting a Buffer not an encoded string,
    onUploadProgress: null
  })
  } catch (e){
    console.log('ERRRR ============')
    console.log(e)
  }
}
test()
