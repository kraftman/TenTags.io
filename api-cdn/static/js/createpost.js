
require('selectize');
var Dropzone = require('dropzone');


Dropzone.autoDiscover = false;

var createpost = function(userID, userSettings){
  this.userID = userID;
  this.userSettings = userSettings;
  this.knownFilters = [];
}

createpost.prototype = function(){
  var load = function(){
    $('#upload_file').hide();
    addDropzone.call(this);
    addSelectize.call(this);
    addNewPostFilterSearch.call(this);
    overrideSubmit.call(this);
  },
  addOptions = function(query){
    var context = this;
    var select = $('#selectedfilters')[0].selectize

    $.get('/api/filter/search/'+query, {
        search: query
    }, function(filters){

      if (filters.error == false){
        $.each(filters.data,function(k,v) {

          context.knownFilters.push(v)
          console.log('adding: ',v.name)
          select.addOption({text: v.name,value: v.name})
        })
        select.refreshOptions()
        console.log(filters)
      }
    });
  },
  updateFilterStyles = function(){
    var filterSelect = $('#selectedfilters')[0].selectize
    var tagSelect = $('#selectedtags')[0].selectize
    var chosenFilters = filterSelect.getValue().split(' ')
    var chosenTags = tagSelect.getValue().split(' ')
    var context = this;

    $.each(chosenFilters,function(k,filterName){
      let selectedFilter = $.grep(context.knownFilters, function(n,i){
        return n.name == filterName
      })[0]
      var filterItem = filterSelect.getItem(filterName)
      filterItem.removeClass('banned')
      if (selectedFilter === undefined) {
        console.log('couldnt find filter: ', filterName)
      }
      $.each(selectedFilter.bannedTagNames,function(k,bannedTag){

        $.each(chosenTags,function(k,tagName){
          if (bannedTag == tagName ){
            SetBanned(filterName, tagName)
          }
        })
      })
    })
  },
  getPostFilters = function(input, callback){
    console.log('this')
    $.get('/api/filter/search/'+input, {
            search: input
         }, function(filters){
           console.log(filters);
           callback({})
         });
  },
  setBanned = function(filterName, tagName){
    console.log('this ', filterName, tagName)
    var filterSelect = $('#selectedfilters')[0].selectize
    var tagSelect = $('#selectedtags')[0].selectize

    var filterItem = filterSelect.getItem(filterName)
    var tagItem = tagSelect.getItem(tagName)

    $(tagItem).addClass('banned');
    $(filterItem).addClass('banned');
  },
  updateFilterSelect = function(filters){
    var filterContainer  = $('#filterselect')
      var context = this;
    $.each(filters.data, function(index,filter){
      context.knownFilters.push(filter)
      filterContainer.append('<option value="'+filter.name+'">'+filter.name+'</option>');
      filterContainer.trigger("chosen:updated");
    })
  }
  overrideSubmit = function(){
    $('#submitButton').click( function(e) {
      e.preventDefault();
      // get the selected tags from chosen
      var selectedtags =  $("#selectedtags").val()
      // get the selected images with descriptions from dropzone


      var uploadedImages = []
      $('.dz-complete').each( function(){
        var imageID = $(this).data('fileID')
        var imageDescription = $(this).find('.form-input').first().val()
        console.log(imageID)
        console.log( imageDescription)
        uploadedImages.push({id: imageID, text: imageDescription})
      })


      var form = {
        selectedtags: JSON.stringify(selectedtags),
        posttitle: $('#posttitle').val(),
        postlink: $('#postlink').val(),
        posttext: $('#posttext').val(),
        postimages: JSON.stringify(uploadedImages)
      }
      $.ajax({
        type: "POST",
        url: '/p/new',
        data: form,
        success: function(data) {
          //console.log('this '+data)
          //console.log(data)
          console.log('worked')
          console.log(data)
          if (data.data.id) {
            window.location.assign('/p/'+data.data.id);
          }
          $('#submitError').html(data.data);
          return false;
        },
        error: function(data) {
          console.log('that');
          console.log(data.responseText);
        },
        dataType: 'json'
      });
    });
    return false;
  },
  filterSelected = function(value,item){
    console.log(value)
    console.log(item)
    var context = this;

    var selectedFilter = $.grep(context.knownFilters, function(n,i){
      console.log(n,i)
      return n.name == value
    })[0]

    var tagSelect = $('#selectedtags')[0].selectize

    $.each(selectedFilter.requiredTagNames,function(k,v){
      tagSelect.addOption({text: v,value: v})
      tagSelect.refreshOptions()
      tagSelect.addItem(v)
      console.log('adding ',v,' to tagSelect')
    })
    tagSelect.refreshOptions()

    updateFilterStyles.call(context)

    overrideSubmit.call(context);

  },
  addNewPostFilterSearch = function(){

    var context = this;
    var filterSelect = $('#selectedfilters').selectize({
      plugins: ['remove_button'],
      delimiter: ' ',
      persist: false,
      create: false,
      onType: function(query) {addOptions.call(context, query)},
      onItemAdd: function(value,item) {filterSelected.call(context,value,item)}

    })
  },
  addSelectize = function(){
    $('#selectedtags').selectize({
      plugins: ['remove_button'],
      delimiter: ' ',
      persist: false,
        create: function(input) {
          return {
              value: input,
              text: input
          }
      }});
  },

  addDropzone = function(){
    $("#image-dropzone").dropzone({
        maxFiles: 20,
        url: "/api/i/",
        thumbnailWidth: 300,
        thumbnailHeight: 200,
        previewTemplate: $('#template-preview').html(),
        success: function (file, response) {
            console.log(response);
            console.log(file.previewElement);
            $(file.previewElement).data('fileID', response.data)
        }
    });

    $("#image-dropzone").sortable({
        items:'.dz-preview',
        cursor: 'move',
        opacity: 0.5,
        containment: '#image-dropzone',
        distance: 20,
        tolerance: 'pointer',
        dictDefaultMessage: 'test test'
    });
  };

  return {
    load: load,
  };
}();

module.exports = createpost;
