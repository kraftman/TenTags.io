var B2 = require('backblaze-b2');
var fs = require ('fs')
var sha1 = require ('node-sha1')
var splitSync = require('node-split').splitSync;


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

var Module = function(file) {
  this.time = (new Date).getTime()
  this.filePath = file.filePath
  this.fileName = this.time+file.fileName
  this.bucketID = bucketID

  this.b2 = new B2({
      accountId: 'a872155e29d7',
      applicationKey: '00198e928abe288f6ac863598106f2aaffd3d1d34e'
  });
};

Module.prototype = function() {

  var Run = async function(position){
    try {
      getBucketName.call(this);
      var test = await this.b2.authorize();
      var fileSize = fs.statSync(this.filePath).size / 1000000.0 //megabytes
      //console.log(fileSize,fs.statSync(this.filePath))
      if (fileSize > 10) {
        await loadLargFile.call(this)
        await startLargeFile.call(this);
        await uploadParts.call(this);
        await finishLargeFile.call(this);
      } else {

        await loadFile.call(this);
        await getUploadUrl.call(this);
        await uploadFile.call(this);
      }

      //await createBucket.call(this);

    } catch (e){
      console.log('ERRRR ============')
      console.log(e)
    }
  },
  loadFile = async function() {

    this.fileBuffer = await loadFileAsync(this.filePath);
  },
  loadLargFile = async function() {
    var fileBuffer = await loadFileAsync(this.filePath);
    this.splitted = splitSync(fileBuffer, {
        bytes: '10M' // 20 * 1024 bytes per files
    });
    console.log('splitted: ',this.splitted.length)

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
  uploadParts = async function(partNum){
    try {
      for (var i = 0; i < this.splitted.length; i++) {
        let buf = this.splitted[i]
        console.log('getting upload part')
        let resp = await this.b2.getUploadPartUrl({fileId: this.fileID})
        let uploadURL = resp.data.uploadUrl
        let authToken = resp.data.authorizationToken
        console.log(uploadURL, authToken)
        console.log('uploading part')

        let response = await this.b2.uploadPart({
          partNumber: i+1,
          uploadUrl: uploadURL,
          uploadAuthToken: authToken,
          data: buf
        })

      }
    } catch (e) {
      console.log('unable to upload multi part: ', e)
    }
  }
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
      var resp = await this.b2.finishLargeFile({
        fileId: this.fileID,
        partSha1Array: this.splitted.map(function(buf) {return sha1(buf)})
      })
    } catch (e) {
      console.log(e)
    }
  },
  uploadFile = async function() {
    try {
      var response  = await this.b2.uploadFile({
        uploadUrl: this.uploadURL,

        uploadAuthToken: this.authToken,
        filename: this.fileName,
        mime: '', // optonal mime type, will default to 'b2/x-auto' if not provided
        data: this.fileBuffer, // this is expecting a Buffer not an encoded string,
        onUploadProgress: null
      })
      if (response.status == 200 ) {
        console.log(response.data)

        Object.keys(response).forEach(function(key) {
          console.log(key)
        });
      } else {
        console.log('non 200 status code returned: ', response.status)
        console.log(response.data)

      }
    } catch (e) {
      console.log('unable to upload file: ', e)
    }
  }



  return {
    Run: Run
  };
}();


module.exports = Module;
