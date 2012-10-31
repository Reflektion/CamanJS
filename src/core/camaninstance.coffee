# This is the main class that you interact with once Caman is actaully initialized.
# It stores all of the important data relevant to a Caman-initialized canvas, and is also 
# responsible for the actual initialization.
class CamanInstance
  @Type =
    Image: 1
    Canvas: 2
    Unknown: 3
    Node: 4

  @toString = Caman.toString

  # All of the arguments given to the Caman() function are simply thrown here.
  constructor: (args, type = CamanInstance.Type.Canvas) ->
    # Every instance gets a unique ID. Makes it much simpler to check if two variables are the 
    # same instance.
    @id = Util.uniqid.get()
    @analyze = new Analyze @
    @pixelStack = []  # Stores the pixel layers
    @layerStack = []  # Stores all of the layers waiting to be rendered
    @renderQueue = [] # Stores all of the render operatives
    @canvasQueue = [] # Stores all of the canvases to be processed
    @currentLayer = null

    # DOM initialization check (if applicable)
    if type is CamanInstance.Type.Node
      @loadNode.apply @, args
    else
      if document.readyState is "complete"
        @domLoaded(args, type)
      else
        listener = =>
          if document.readyState is "complete"
            @domLoaded(args, type)
        document.addEventListener "readystatechange", listener, false
    
  domLoaded: (args, type) ->
    # Begin initialization
    switch type
      when CamanInstance.Type.Image then @loadImage.apply @, args
      when CamanInstance.Type.Canvas then @loadCanvas.apply @, args
      when CamanInstance.Type.Unknown then @loadUnknown args

  loadUnknown: (args) ->
    e = $(args[0])
    switch e.nodeName.toLowerCase()
      when "img" then @loadImage.apply @, args
      when "canvas" then @loadCanvas(null, args[0], args[1])
      
  ########## Begin Image Loading ##########
  
  loadImage: (sel, callback = ->) ->   
    if typeof sel is "object" and sel.nodeName?.toLowerCase() is "img"
      image = sel
      image.id = "caman-#{Util.uniqid.get()}" unless image.id
    else
      image = $(sel)
      if not image
        throw "Could not find element #{sel}"
      if image.nodeName.toLowerCase() isnt "img"
        throw "Given element ID isn't an image: #{sel}"

    proxyURL = IO.remoteCheck image.src
    if proxyURL
      image.onload = => @imageLoaded image, callback
      image.src = proxyURL
    else
      if image.complete
        @imageLoaded image, callback
      else
        image.onload = => @imageLoaded image, callback
        
  imageLoaded: (image, callback) ->
    @image = image
    @canvas = document.createElement 'canvas'
    @canvas.id = image.id
    
    for attr in ['data-camanwidth', 'data-camanheight']
      @canvas.setAttribute attr, @image.getAttribute(attr) if @image.getAttribute attr

    image.parentNode.replaceChild @canvas, @image if image.parentNode?

    @finishInit callback

  ########## End Image Loading ##########
  
  ########## Begin Canvas Loading ##########
  
  loadCanvas: (url, sel, callback = ->) ->
    if typeof sel is "object" and sel.nodeName?.toLowerCase() is "canvas"
      element = sel
      element.id = "caman-#{Util.uniqid.get()}" unless element.id
    else
      element = $(sel)
      if not element
        throw "Could not find element #{sel}"
      if element.nodeName.toLowerCase() isnt "canvas"
        throw "Given element ID isn't a canvas: #{sel}"

    @canvasLoaded url, element, callback
      
  canvasLoaded: (url, canvas, callback) ->
    @canvas = canvas
    @canvas.id

    if url?
      @image = document.createElement 'img'
      @image.onload = => @finishInit callback
      proxyURL = IO.remoteCheck(url)
      @image.src = if proxyURL then proxyURL else url
    else
      @finishInit callback
  
  ########## End Canvas Loading ##########

  loadNode: (file, callback) ->
    img = new Image()
    file = fs.realpathSync file if typeof file is "string"

    img.onload = =>
      @canvas = new Canvas img.width, img.height
      @canvas.id = Util.uniqid.get()
      
      context = @canvas.getContext '2d'
      context.drawImage img, 0, 0

      @finishInit callback

    img.onerror = (err) -> throw err

    img.src = file
    
  finishInit: (callback) ->
    @context = @canvas.getContext("2d")
    
    if @image?
      oldWidth = @image.width
      oldHeight = @image.height
      newWidth = @canvas.getAttribute 'data-camanwidth'
      newHeight = @canvas.getAttribute 'data-camanheight'

      # Image resizing
      if newWidth or newHeight
        if newWidth
          @image.width = parseInt newWidth, 10

          if newHeight
            @image.height = parseInt newHeight, 10
          else
            @image.height = @image.width * oldHeight / oldWidth
        else if newHeight
          @image.height = parseInt newHeight, 10
          @image.width = @image.height * oldWidth / oldHeight

      @canvas.width = @image.width
      @canvas.height = @image.height

      if window.devicePixelRatio
        @canvas.style.width = "#{@image.width}px"
        @canvas.style.height = "#{@image.height}px"
        @canvas.width = @image.width * window.devicePixelRatio
        @canvas.height = @image.height * window.devicePixelRatio
        @context.scale(window.devicePixelRatio, window.devicePixelRatio)

      @context.drawImage(@image, 0, 0, @image.width, @image.height)

    @imageData = @context.getImageData(0, 0, @canvas.width, @canvas.height)
    @pixelData = @imageData.data

    @dimensions =
      width: @canvas.width
      height: @canvas.height
      
    Store.put @canvas.id, @
    
    # haha, owl face.
    callback.call @,@
    return @

  replaceCanvas: (newCanvas) ->
    oldCanvas = @canvas
    @canvas = newCanvas
    @canvas.id = oldCanvas.id

    if oldCanvas.parentNode?
      oldCanvas.parentNode.replaceChild @canvas, oldCanvas

    @context = @canvas.getContext '2d'
    @imageData = @context.getImageData 0, 0, @canvas.width, @canvas.height
    @pixelData = @imageData.data
    @dimensions =
      width: @canvas.width
      height: @canvas.height
    