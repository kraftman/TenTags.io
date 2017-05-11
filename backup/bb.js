var B2 = require('backblaze-b2');
var fs = require ('fs')
var sha1 = require ('node-sha1')


var bucketID = '7af8c7029115f53e52b90d17'


function loadFileAsync(path) {
  return new Promise(function (resolve, reject) {
    fs.readFile(path, function (error, result) {
      if (error) {
        reject(error);
      } else {
        resolve(result);
      }
    });
  });
}

var Module = function(filePath) {
  this.time = (new Date).getTime()
  this.filePath = filePath
  this.fileName = 'backup-'+this.time
  this.bucketID = bucketID

  this.b2 = new B2({
      accountId: 'a872155e29d7',
      applicationKey: '00198e928abe288f6ac863598106f2aaffd3d1d34e'
  });
};

Module.prototype = function() {

  var Run = async function(position){
    try {
    var test = await this.b2.authorize();
    await loadFile.call(this)

    var bucketName = await getBucketName.call(this)
    await loadFile.call(this);
    await getBucketName.call(this);
    //await createBucket.call(this);
    //await getUploadUrl.call(this);
    //await uploadFile.call(this);
    await startLargeFile.call(this);
    await getUploadPartUrl.call(this);
    await uploadPart.call(this);
    await finishLargeFile.call(this);



    } catch (e){
      console.log('ERRRR ============')
      console.log(e)
    }
  },
  loadFile = async function() {

    this.fileBuffer = await loadFileAsync(this.filePath);
  },
  getBucketName = async function() {
    this.bucketName = 'filttatest-'+this.time
  },
  createBucket = async function() {
    try {
      var response = await this.b2.createBucket(
        this.bucketName,
        'allPrivate' // one of `allPublic`, `allPrivate`
      );
      this.bucketID = response.data.bucketId
      if (this.bucketID === undefined) {
        console.log('unable to get bucket');
      }
    } catch(e) {
      console.log('error creating bucket: ', e)
    }
  },
  getUploadUrl = async function() {
    try {
      var uploadURL = await this.b2.getUploadUrl(this.bucketID)
      this.uploadURL = uploadURL.data.uploadUrl
      this.authToken = uploadURL.data.authorizationToken
    } catch (e) {
      console.log('unable to get upload url:', e)
    }
  },
  getUploadPartUrl = async function() {
    try {
      var uploadURL = await this.b2.getUploadPartUrl({fileId: this.fileID})
      this.uploadURL = uploadURL.data.uploadUrl
      this.authToken = uploadURL.data.authorizationToken
    } catch (e) {
      console.log('unable to get upload url:', e)
    }
  },
  uploadPart = async function() {
    try {
      var response = await this.b2.uploadPart({
        partNumber: 1,
        uploadUrl: this.uploadURL,
        uploadAuthToken: this.authToken,
        data: this.fileBuffer,
        onUploadProgress: function(event){console.log(event)}
      })

    } catch(e) {
      console.log('error uploading part: ', e)
    }
  },
  startLargeFile = async function() {
    try {
      var response = await this.b2.startLargeFile({bucketId: this.bucketID,fileName: this.fileName })
      this.fileID = response.data.fileId
    } catch (e) {
      console.log('unable to get large file start:', e)
    }
  },
  finishLargeFile = async function() {
    try {
      var resp = await this.b2.finishLargeFile({fileId: this.fileID,partSha1Array: [sha1(this.fileBuffer)] })
    } catch (e) {

    }
  },
  uploadFile = async function() {
    try {
      var response  = await this.b2.uploadFile({
        uploadUrl: this.uploadURL,

        uploadAuthToken: this.authToken,
        filename: 'Dockerfile',
        mime: '', // optonal mime type, will default to 'b2/x-auto' if not provided
        data: this.fileBuffer, // this is expecting a Buffer not an encoded string,
        onUploadProgress: null
      })
      console.log(response)
    } catch (e) {
      console.log('unable to upload file: ', e)
    }
  }



  return {
    Run: Run
  };
}();


module.exports = Module;
