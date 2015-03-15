#' Get links to datasets related to a unique ID from an NCBI database
#'
#' Constructs a query with the given arguments and downlands the XML
#' document created by that query. 
#'
#'@import XML
#'@export
#'@param db character Name of the database to search for links (or use "all" to 
#' search all databases available for \code{db}. \code{entrez_db_links} allows you
#' to discover databases that might have linked information (see examples).
#'@param dbfrom character Name of database from which the Id(s) originate
#'@param cmd link function to use
#'@param \dots character Additional terms to add to the request
#'@param config vector configuration options passed to httr::GET  
#'@seealso \code{\link[httr]{config}} for available configs 
#'@return An elink object containing vectors of unique IDs
#' the vectors names take the form [db_from]_[db_to]
#'@return file XMLInternalDocument xml file resulting from search, parsed with
#'\code{\link{xmlTreeParse}}
#' @examples
#' \donttest{
#'  (pubmed_search <- entrez_search(db = "pubmed", term ="10.1016/j.ympev.2010.07.013[doi]"))
#'  (linked_dbs <- entrez_db_links("pubmed"))
#'  nucleotide_data <- entrez_link(dbfrom = "pubmed", id = pubmed_search$ids, db ="nuccore")
#'  #All the links
#'  entrez_link(dbfrom="pubmed", db="all", id=pubmed_search$ids)
#'}
#'


entrez_link <- function(db, dbfrom, cmd='neighbor', config=NULL, ...){

    response <- make_entrez_query("elink", db=db, dbfrom=dbfrom, cmd=cmd,
                                  config=config, ..., 
                                  require_one_of=c("id", "WebEnv"))
    record <- parse_response(response, 'xml')
    search_ids <- XML::xpathSApply(record, "//IdList/Id", 
                                   function(x) as.numeric(XML::xmlValue(x))
    )
    Sys.sleep(0.33)
    parse_elink(record, cmd=cmd)
}

#    if(-1 %in% search_ids){
#       msg <- paste("Some  IDs not found in", dbfrom)
#       warning(msg)
#    }
#    db_names <- XML::xpathSApply(record, "//LinkName", XML::xmlValue)
#
#    # Get ID from each database
#    # Not simplified so if a single database get a named list (for consistancy)
#    result <- sapply(db_names, get_linked_ids, record=record, simplify=FALSE)
#    result$file <- record
#    class(result) <- c("elink", class(result))
#    #NCBI limits requests to three per second
#    Sys.sleep(0.33)
#    return(result)
#}

#' @export

parse_elink <- function(x, cmd){
    switch(cmd,
           "neighbor"         = parse_neighbors(x),
           "neighbor_score"   = parse_neighbors(x),
           "neighbor_history" = parse_history(x),
           "ncheck"           = parse_ncheck(x),
           x)
}

parse_neighbors <- function(x){
    db_names <- XML::xpathSApply(x, "//LinkName", XML::xmlValue)
    result <- sapply(db_names, get_linked_elements, record=x, element="Id", simplify=FALSE)
    attr(result, "scores") <- sapply(db_names, get_linked_elements, record=x, element="Score", simplify=FALSE)
    attr(result, "content") <- "linked IDs"
    class(result) <- c("elink", class(result))
    result
}

parse_history <- function(x){
    qks <-    XML::xpathSApply(x, "//LinkSetDbHistory/QueryKey", XML::xmlValue)
    names(qks) <-    XML::xpathApply(x, "//LinkSetDbHistory/LinkName", XML::xmlValue)
    cookie <- XML::xmlValue(x[["//WebEnv"]])
    res <- list(cookie = cookie, QueryKeys=qks)
    attr(res, "content") <- "web history information"
    res
}

parse_ncheck <- function(x){
    res <- structure(names= XML::xpathSApply(x, "//Id", XML::xmlValue),
                     x["//Id/@HasNeighbor"] == "Y")
    attr(res, "content") <- "link checks"
    class(res) <- c("elink", class(res))
    res
}

    

parse_linkouts <- function(x){
}


#' @export
print.elink <- function(x, ...){
   len <- length(x)
   cat(paste("elink result with ids from", len - 1, "databases:\n"))
   print (names(x)[-len], quote=FALSE)
}

get_linked_elements <- function(record, dbname, element){
    path <-  paste0("//LinkSetDb/LinkName[text()='", dbname, "']/../Link/", element)
    return(XML::xpathSApply(record, path, XML::xmlValue))
}
