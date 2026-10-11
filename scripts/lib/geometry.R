validate_geometry <- function(geometry,label) {
  if (!geometry$type %in% c('Polygon','MultiPolygon')) stop('Unsupported geometry type for ',label)
  polygons <- if (geometry$type=='Polygon') list(geometry$coordinates) else geometry$coordinates
  if (!length(polygons)) stop('Empty geometry: ',label)
  for (polygon in polygons) {
    if (!length(polygon)) stop('Empty polygon: ',label)
    for (ring in polygon) {
      if (length(ring)<4 || any(lengths(ring)!=2)) stop('Invalid ring dimensions: ',label)
      xy <- do.call(rbind,lapply(ring,unlist))
      if (!is.numeric(xy) || any(!is.finite(xy)) || any(abs(xy[,1])>180) || any(abs(xy[,2])>90)) stop('Invalid WGS84 coordinates: ',label)
      if (any(xy[1,]!=xy[nrow(xy),])) stop('Unclosed polygon ring: ',label)
      if (nrow(unique(xy))<3) stop('Degenerate polygon ring: ',label)
      signed_area <- sum(xy[-nrow(xy),1]*xy[-1,2]-xy[-1,1]*xy[-nrow(xy),2])/2
      if (abs(signed_area)<1e-13) stop('Zero-area polygon ring: ',label)
    }
  }
  invisible(TRUE)
}
canonical_zone <- function(value) {
  value <- sub('^NO-','',value)
  gsub('_','',value,fixed=TRUE)
}
assemble_geometry <- function(tables,root) {
  g <- tables$geography_config[tables$geography_config$active=='TRUE',,drop=FALSE]
  provenance <- read_json(file.path(root,'config/geography_sources.json'))
  records <- setNames(provenance$active_inputs,vapply(provenance$active_inputs,function(x) x$file,character(1)))
  features <- list(); inputs <- list()
  for (i in seq_len(nrow(g))) {
    path <- file.path(root,g$geojson_file[i])
    if (!file.exists(path)) stop('Missing configured map: ',g$bidding_zone[i])
    record <- records[[g$geojson_file[i]]]
    if (is.null(record) || record$sha256 != sha_file(path)) stop('Map differs from its provenance register: ',g$bidding_zone[i])
    inputs[[g$geojson_file[i]]] <- sha_file(path)
    doc <- read_json(path)
    crs <- doc$crs$properties$name
    if (!is.null(crs) && !crs %in% c('urn:ogc:def:crs:OGC:1.3:CRS84','urn:ogc:def:crs:EPSG::4326','EPSG:4326')) stop('Map requires reprojection: ',path)
    candidates <- if (doc$type=='FeatureCollection') doc$features else if (doc$type=='Feature') list(doc) else stop('Map must contain GeoJSON features')
    zones <- vapply(candidates,function(f) canonical_zone(f$properties$bidding_zone %||% f$properties$zoneName %||% ''),character(1))
    selected <- which(zones==g$bidding_zone[i])
    if (length(selected)!=1) stop('Expected exactly one named feature for ',g$bidding_zone[i])
    f <- candidates[[selected]]
    validate_geometry(f$geometry,g$bidding_zone[i])
    f$id <- g$bidding_zone[i]
    f$properties <- list(country=g$country[i],country_name=g$country_name[i],bidding_zone=g$bidding_zone[i],zone_name=g$zone_name[i],
      provenance_status=record$provenance_status,source_url=record$source_url,license=record$license)
    features[[length(features)+1]] <- f
  }
  if (length(features)!=nrow(g) || anyDuplicated(vapply(features,function(f)f$id,character(1)))) stop('Incomplete or duplicate map coverage')
  list(geojson=list(type='FeatureCollection',features=features),input_hashes=inputs,provenance=provenance)
}
