window.IxMap = {}

class IxMap.Search

  @featuresJson: '/api/v2/features.json'
  @searchJson: '/api/v2/search.json' 
  @searchFieldId: '#search'
  @exchangeLatLons: []

  lookupFromSearchTerm: (@searchName) -> 
    jQuery.getJSON IxMap.Search.searchJson, (data) =>
      jQuery(IxMap.Search.searchFieldId).val("Search").blur()
      for exchange in data
        if exchange.value == @searchName
          jQuery(location).attr('href',"#{exchange.url}")

  constructor: (@map) ->
    jQuery.getJSON IxMap.Search.searchJson, (data) =>
      jQuery(IxMap.Search.searchFieldId).autocomplete {
      position: {my: "right top+12", at: "right bottom" },
      source: data,
      select: (event, ui) => @lookupFromSearchTerm(ui.item.value)
      }
    jQuery(IxMap.Search.searchFieldId).val("Search").focus(() ->
      jQuery(this).addClass("focus")
      jQuery("#nav .search-container").addClass("focus")
      jQuery(this).val("") if jQuery(this).val() == "Search"
    ).blur( () ->
      jQuery(this).removeClass("focus").val("Search")
      jQuery("#nav .search-container").removeClass("focus")
    )

class IxMap.Map

  @informationMarkupId: "#information"
  @markerPath: '/assets/images/markers.png'
  @buildingsGeojson: '/api/v2/buildings.geojson'
  @exchangesListJson: '/api/v2/exchanges.json'
  @alphabet: "abcdefghijklmnopqrstuvwxyz".split("")
  @iconObj: {url:'/assets/images/markers.png',size:new google.maps.Size(22,29),origin:new google.maps.Point(0,0)}
  @buildingZoomLevel: 12

  @showAllExchanges: () ->
    exchangeList = []
    jQuery.getJSON IxMap.Map.exchangesListJson, (data) -> 
      for exchange, i in data
        exchangeList.pushObject({id: i, name: exchange.value, slug: IxMap.Map.toSlug(exchange.value)})
    exchangeList

  @toSlug: (str) ->
    str.toLowerCase().replace(/[^-a-z0-9~\s\.:;+=_]/g,'').replace(/[\s\.:;=+]+/g, '-')

  lookupExchangeForMap: (@searchName) ->
    @clearAllBuildings()
    jQuery.getJSON IxMap.Search.featuresJson, (data) =>
      exchanges = []
      @bounds(jQuery.map data, (exchange, i) =>
        if exchange.slug_name == @searchName
          exchanges.push(exchange.building_id)
          {latitude:exchange.latitude, longitude:exchange.longitude})
      @clearAllBuildings()
      @showSearchBuildings(exchanges)
      jQuery(IxMap.Search.searchFieldId).val("Search").blur()

  lookupCountryOrMetroAreaForMap: (@searchName, type = "country") ->
    @clearAllBuildings()
    buildingList = []
    for building in @buildings
      if building.geojsonProperties[type] == IxMap.Map.toSlug(@searchName)
        building.setIcon({url:'/assets/images/markers.png',size:new google.maps.Size(22,29),origin:new google.maps.Point(1166,0)})
        @setSearchResultMarkerEventListener(building)
        building.setMap(@gmap)
        buildingList.push({map:this, building:building, letter:0})
    @bounds(for building in buildingList
      {latitude:building.building.getPosition().lat(), longitude:building.building.getPosition().lng()})
    buildingList
    jQuery(IxMap.Search.searchFieldId).val("Search").blur()

  lookupBuildingForMap: (@searchName) ->
    @infoBox.close()
    @clearAllBuildings()
    @showAllBuildings()
    for building in @buildings
      if building.geojsonProperties.building_id == parseInt( @searchName, 10 )
        @selectBuildingFromList(building)
        @gmap.setZoom(IxMap.Map.buildingZoomLevel) if @gmap.getZoom() < 12

  showAllExchanges: () ->
    @exchangeList = [] if !@exchangeList
    jQuery.getJSON IxMap.Map.exchangesListJson, (data) => 
      for exchange, i in data
        @exchangeList.pushObject({id: i, name: exchange.value})
    @exchangeList

  selectBuildingFromList: (building, color = 'blue') ->
    @infoBox.close()
    jQuery(location).attr('href',"/#/building/#{building.geojsonProperties.building_id}")
    infoMarkup = jQuery('<div/>').addClass("#{color}-info-box-content").append(jQuery('<div/>').addClass("#{color}-info-box-pointer"))
    @gmap.panTo(building.position)
    for addr in building.geojsonProperties.address
      infoMarkup.append(jQuery("<div/>").text(addr))
    @infoBox.setContent(jQuery('<div/>').append(infoMarkup).html())
    @infoBox.setPosition(building.position)
    @infoBox.open(@gmap)

  highlightExchangeBuildingFromList: (buildingId, color = 'red') ->
    for building in @buildings
      if building.geojsonProperties.building_id == parseInt( buildingId, 10 )
        this.infoBox.close()
        infoMarkup = jQuery('<div/>').addClass("#{color}-info-box-content").append(jQuery('<div/>').addClass("#{color}-info-box-pointer"))
        for addr in building.geojsonProperties.address
          infoMarkup.append(jQuery("<div/>").text(addr))
        this.infoBox.setContent(jQuery('<div/>').append(infoMarkup).html())
        this.infoBox.setPosition(building.position)
        this.infoBox.open(@gmap)

  highlightExchangeBuilding: (building, color = 'red') ->
    this.infoBox.close()
    infoMarkup = jQuery('<div/>').addClass("#{color}-info-box-content").append(jQuery('<div/>').addClass("#{color}-info-box-pointer"))
    for addr in building.geojsonProperties.address
      infoMarkup.append(jQuery("<div/>").text(addr))
    this.infoBox.setContent(jQuery('<div/>').append(infoMarkup).html())
    this.infoBox.setPosition(building.position)
    this.infoBox.open(@gmap)

  clearAllBuildings: () ->
    @infoBox.close()
    for building in @buildings
      google.maps.event.clearInstanceListeners building
      building.setIcon(IxMap.Map.iconObj)
      building.setMap(null)

  onClickMapEvent: () ->
    google.maps.event.addListener @gmap, 'click', (event) =>
      @infoBox.close()
      @clearAllBuildings()
      for building in @buildings
        @setMarkerEventListener(building)
        building.setMap(@gmap)
      jQuery(location).attr('href','/#/')

  setMarkerEventListener: (building) ->
    google.maps.event.addListener building, 'click', (event) =>
      @selectBuildingFromList(building)

  setSearchResultMarkerEventListener: (building) ->
    google.maps.event.addListener building, 'mouseover', (event) =>
      @highlightExchangeBuilding(building, 'red')
    google.maps.event.addListener building, 'mouseout', (event) =>
      @infoBox.close()
    google.maps.event.addListener building, 'click', (event) =>
      google.maps.event.clearListeners building, 'mouseout'
      @selectBuildingFromList(building, 'red')

  showSearchBuildings: (exchange) ->
    @clearAllBuildings()
    buildingList = []
    x = 0
    for building in @buildings
      if included = building.geojsonProperties.building_id in exchange
        if (x+1)*22 > 1166
          building.setIcon({url:'/assets/images/markers.png',size:new google.maps.Size(22,29),origin:new google.maps.Point(1166,0)})
        else
          building.setIcon({url:'/assets/images/markers.png',size:new google.maps.Size(22,29),origin:new google.maps.Point((x+1)*22,0)})
        
        @setSearchResultMarkerEventListener(building)
        building.setMap(@gmap)
        buildingList.push({map:this, building:building, letter:x})
        x++
    buildingList

  showAllBuildings: () ->
    @clearAllBuildings()
    for building in @buildings
      @setMarkerEventListener(building)
      building.setIcon(IxMap.Map.iconObj)
      building.setMap(@gmap)

  bounds: (exchangeLatLons) -> 
    if exchangeLatLons.length > 1
      cableBounds = new google.maps.LatLngBounds()
      for point in exchangeLatLons
        cableBounds.extend(new google.maps.LatLng(point.latitude, point.longitude))
      @gmap.fitBounds(cableBounds);
    else
      @gmap.setCenter(new google.maps.LatLng(exchangeLatLons[0].latitude,exchangeLatLons[0].longitude));
      @gmap.setZoom(10)

  constructor: (@element, @center, @zoom, @buildings) ->
    @gmap = new google.maps.Map(document.getElementById(@element), { 
        zoom: @zoom,
        streetViewControl: false,
        mapTypeControl: false,
        maxZoom: 20,
        minZoom: 2,
        styles: [{featureType: "all",elementType: "all", stylers: [{ "gamma": 1.7 }]}],
        center: @center
        mapTypeId: google.maps.MapTypeId.ROADMAP
      })
    @infoBox = new InfoBox({closeBoxURL:"",alignBottom:true,pixelOffset:new google.maps.Size(-60,-45)})
    @search = new IxMap.Search(this)
    @showAllBuildings()
    @onClickMapEvent()
    return this
