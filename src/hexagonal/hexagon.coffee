Point    = require './core/point.coffee'
Size     = require './core/size.coffee'
Vertex   = require './core/vertex.coffee'
Edge     = require './core/edge.coffee'
HalfEdge = require './core/half_edge.coffee'

round    = require('./core/util.coffee').round

# Hexagon
#
# @example Built using Radius
#   Hexagon.byRadius 2 # built with radius 2 and center placed in the origin
#   Hexagon.byRadius center: { x: 1, y: 2 }, radius: 2
#
# @example Built using Vertices
#   Hexagon.byVertices [v1, v2, v3, v4, v5, v6]
#
# @example Built using Edges
#   Hexagon.byEdges [e1, e2, e3, e4, e5, e6]
#
# @example Built using Size
#   Hexagon.bySize { width: 10, height: 10 } # with position placed in the origin
#   Hexagon.bySize { width: 10 },  position: { x: 1, y: 2} # height will be detected
#   Hexagon.bySize { height: 10 }, position: { x: 1, y: 2} # width will be detected
#
# When you create an hexagon you should always pass the flatTopped option set to true if you want
# the hexagon to be handled as flat topped.
#
# @example
#   Hexagon.bySize { width: 10, height: 10 } # creates a pointy topped hexagon
#   Hexagon.bySize { width: 10, height: 10 }, flatTopped: true # creates a flat topped hexagon
class Hexagon
  @sizeMultipliers:
    pointly: [
      { x: 1,   y: 0.75 },
      { x: 0.5, y: 1 },
      { x: 0,   y: 0.75 },
      { x: 0,   y: 0.25 },
      { x: 0.5, y: 0 },
      { x: 1,   y: 0.25 }
    ],
    flat: [
      { x: 1,    y: 0.5 },
      { x: 0.75, y: 1 },
      { x: 0.25, y: 1 },
      { x: 0,    y: 0.5 },
      { x: 0.25, y: 0 },
      { x: 0.75, y: 0 }
    ]
  @dimensionCoeff: Math.sqrt(3) / 2

  # Creates a regular Hexagon given its radius
  # @param radius [Number] radius of the circle inscribing the hexagon
  # @param attributes [Hash] Options to provide:
  #   center: center of the hexagon
  #   flatTopped: whether to create a flat topped hexagon or not
  #   position: position to set when the hexagon has been built
  @byRadius: (radius, attributes = {}) ->
    center = new Point attributes.center
    vertices = []
    for index in [0...6]
      angleMod = if attributes.flatTopped then 0 else 0.5
      angle    = 2 * Math.PI / 6 * (index + angleMod)
      vertices.push new Vertex
        x: round(center.x + radius * Math.cos(angle))
        y: round(center.y + radius * Math.sin(angle))
    @byVertices vertices, attributes

  @_detectedSize: (size, flatTopped) ->
    [width, height] = [size.width, size.height]
    coeff = if flatTopped then 1 / @dimensionCoeff else @dimensionCoeff
    if width
      new Size width, height ? round(width / coeff)
    else if height
      new Size round(height * coeff), height

  # Creates an Hexagon given its size
  # @param size [Size] Size to use to create the hexagon
  #   If one of the size values (width or height) is not set, it will be
  #   calculated using the other value, generating a regular hexagon
  # @param attributes [Hash] Options to provide:
  #   flatTopped: whether to create a flat topped hexagon or not
  #   position: position to set when the hexagon has been built
  @bySize: (size, attributes = {}) ->
    unless size?.width? or size?.height?
      throw new Error "Size must be provided with width or height or both"
    size = @_detectedSize size, attributes.flatTopped
    multipliers = @sizeMultipliers[if attributes.flatTopped then 'flat' else 'pointly']
    vertices = []
    for multiplier in multipliers
      vertices.push new Vertex
        x: round(size.width  * multiplier.x)
        y: round(size.height * multiplier.y)
    @byVertices vertices, attributes

  # Creates an Hexagon given its vertices
  # @param vertices [Array<Vertex>] Collection of vertices
  #   Vertices have to be ordered clockwise starting from the one at
  #   0 degrees (in a flat topped hexagon), or 30 degrees (in a pointly topped hexagon)
  # @param attributes [Hash] Options to provide:
  #   flatTopped: whether this is a flat topped hexagon or not
  #   position: position to set when the hexagon has been built
  @byVertices: (vertices, attributes = {}) ->
    throw new Error 'You have to provide 6 vertices' if vertices.length isnt 6
    edges = (for vertex, index in vertices
      nextVertex = vertices[index + 1] ? vertices[0]
      new Edge [vertex, nextVertex])
    @byEdges edges, attributes

  # Creates an Hexagon given its edges
  # @param edges [Array<Edge>] Collection of edges
  #   Edges have to be ordered counterclockwise starting from the one with
  #   the first vertex at 0 degrees (in a flat topped hexagon),
  #   or 30 degrees (in a pointly topped hexagon)
  # @param attributes [Hash] Options to provide:
  #   flatTopped: whether this is a flat topped hexagon or not
  #   position: position to set when the hexagon has been built
  @byEdges: (edges, attributes = {}) ->
    throw new Error 'You have to provide 6 edges' if edges.length isnt 6
    halfEdges = (new HalfEdge(edge) for edge in edges)
    new Hexagon halfEdges, attributes

  constructor: (@halfEdges, attributes = {}) ->
    throw new Error 'You have to provide 6 halfedges' if @halfEdges.length isnt 6
    @topMode   = if attributes.flatTopped then 'flat' else 'pointly'
    @_setPosition attributes.position if attributes.position?
    halfEdge.hexagon = @ for halfEdge in @halfEdges

  isFlatTopped: -> @topMode is 'flat'

  isPointlyTopped: -> @topMode is 'pointly'

  vertices: -> (halfEdge.va() for halfEdge in @halfEdges)

  edges: -> (halfEdge.edge for halfEdge in @halfEdges)

  center: => @position().sum @size().width / 2, @size().height / 2

  position: (value) => if value? then @_setPosition(value) else @_getPosition()

  size: (value) => if value? then @_setSize(value) else @_getSize()

  neighbors: ->
    neighbors = []
    for halfEdge in @halfEdges
      otherHalfEdge = halfEdge.otherHalfEdge()
      if otherHalfEdge? and neighbors.indexOf(otherHalfEdge.hexagon) < 0
        neighbors.push otherHalfEdge.hexagon
    neighbors

  toString: => "#{@constructor.name}(#{@position().toString()}; #{@size().toString()})"

  isEqual: (other) ->
    return false if @vertices.length isnt (other.vertices?.length ? 0)
    for v, index in @vertices
      return false unless v.isEqual(other.vertices[index])
    true

  toPrimitive: => (v.toPrimitive() for v in @vertices)

  _copyStartingVerticesFromEdges: (attributes) ->
    attributes.vertices ?= []
    for edge, index in attributes.edges when edge?
      attributes.vertices[index]     ?= edge.va
      attributes.vertices[index + 1] ?= edge.vb

  _round: (value) -> round(value)

  _getPosition: ->
    vertices = @vertices()
    xVertexIdx = if @isFlatTopped() then 3 else 2
    new Point vertices[xVertexIdx].x, vertices[4].y

  _setPosition: (value) ->
    actual = @_getPosition()
    for vertex in @vertices()
      vertex.x = round(vertex.x - actual.x + value.x)
      vertex.y = round(vertex.y - actual.y + value.y)

  _getSize: ->
    vertices = @vertices()
    new Size
      width : round Math.abs(vertices[0].x - @position().x)
      height: round Math.abs(vertices[1].y - @position().y)

  _setSize: (value) ->
    position = @_getPosition()
    vertices = @vertices()
    for multiplier, index in @constructor.sizeMultipliers[@topMode]
      vertices[index].x = round(position.x + value.width * multiplier.x)
      vertices[index].y = round(position.y + value.height * multiplier.y)

module.exports = Hexagon
