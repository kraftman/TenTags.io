var knownFilters = [];


$(function() {

  //$("#tagselect").chosen();
  //$('#filterselect').chosen();
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


      var tagSelect = $('#selectedtags')[0].selectize
        tagSelect.addOption({text: 'foo',value: 'fee'})
  AddNewPostFilterSearch()
  AddPostFilterSearch()

});

function GetPostFilters(input, callback){
  console.log('this')
  $.get('/api/filter/search/'+input, {
          search: input
       }, function(filters){
         console.log(filters);
         callback({})
       });
}

function AddOptions(query){

  var select = $('#selectedfilters')[0].selectize

  $.get('/api/filter/search/'+query, {
      search: query
  }, function(filters){

    if (filters.error == false){
      $.each(filters.data,function(k,v) {

        knownFilters.push(v)
        console.log('adding: ',v.name)
        select.addOption({text: v.name,value: v.name})
      })
      select.refreshOptions()
      console.log(filters)
    }
  });
}

function FilterSelected(value, item){
  console.log(value)
  console.log(item)

  var selectedFilter = $.grep(knownFilters, function(n,i){
    console.log(n,i)
    return n.name == value
  })[0]

  var tagSelect = $('#selectedtags')[0].selectize
    tagSelect.addOption({text: 'foo',value: 'fee'})

    tagSelect.refreshOptions()

  $.each(selectedFilter.requiredTagNames,function(k,v){
    tagSelect.addOption({text: v,value: v})

    tagSelect.refreshOptions()
    tagSelect.addItem(v)
    console.log('adding ',v,' to tagSelect')
  })
  tagSelect.refreshOptions()

  UpdateFilterStyles()


}

function SetBanned(filterName, tagName){
  console.log('this ', filterName, tagName)
  var filterSelect = $('#selectedfilters')[0].selectize
  var tagSelect = $('#selectedtags')[0].selectize

  var filterItem = filterSelect.getItem(filterName)
  var tagItem = tagSelect.getItem(tagName)

  $(tagItem).addClass('banned');
  $(filterItem).addClass('banned');
}

function UpdateFilterStyles(){

  //get all the selected filters
  //get all the selected tags
  // for each tag, check if they are banned
  // color them

  var filterSelect = $('#selectedfilters')[0].selectize
  var tagSelect = $('#selectedtags')[0].selectize
  var chosenFilters = filterSelect.getValue().split(' ')
  var chosenTags = tagSelect.getValue().split(' ')



  $.each(chosenFilters,function(k,filterName){
    let selectedFilter = $.grep(knownFilters, function(n,i){
      return n.name == filterName
    })[0]
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


}

function AddNewPostFilterSearch() {

  var filterSelect = $('#selectedfilters').selectize({
    plugins: ['remove_button'],
    delimiter: ' ',
    persist: false,
    create: false,
    onType: AddOptions,
    onItemAdd: FilterSelected

  })

}




function UpdateFilterSelect(filters){
  var filterContainer  = $('#filterselect')
  $.each(filters.data, function(index,filter){
    knownFilters.push(filter)
    filterContainer.append('<option value="'+filter.name+'">'+filter.name+'</option>');
    filterContainer.trigger("chosen:updated");
  })
}

function AddFilterToTags(e,p){


  //update all the other filters
  $.each($('#filterselect_chosen').find('li.search-choice'), function(k,filterElement){
    var filterName = $(filterElement).find('span').text()
    var filter = $.grep(knownFilters, function(n,i){
      console.log(n,i)
      return n.name == filterName
    })[0]

    var foundBannedTag;

    $.each($('#tagselect_chosen').find('li.search-choice'), function(k,tagElement) {
      var tagName = $(tagElement).find('span').text()
      var found;
      $.each(filter.bannedTagNames, function(k,v){
        if (v == tagName){
          found = true;
        }
      })
      if (found == true) {
        foundBannedTag = true
        console.log('test')
        $(tagElement).addClass('banned');
      } else {
        $(tagElement).removeClass('banned');
      }
    })

    if (foundBannedTag == true){
      console.log('marking filter as banned')
      $(filterElement).addClass('banned');
    } else {
      $(filterElement).removeClass('banned');
    }

  })

}

function AddPostFilterSearch(){

  $('#filterselect').change(AddFilterToTags);

  $('#filterselect_chosen').find('input').on('input', function() {

    clearTimeout($(this).data('timeout'));
    var _self = this;
    $(this).data('timeout', setTimeout(function () {
      console.log('searching')

      if (_self.value.trim()){
        $.get('/api/filter/search/'+_self.value+'?withTags=true', {
            search: _self.value
        }, UpdateFilterSelect);
      }
    }, 200));
  })
}
