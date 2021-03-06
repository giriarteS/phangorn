#' Bootstrap
#' 
#' \code{bootstrap.pml} performs (non-parametric) bootstrap analysis and
#' \code{bootstrap.phyDat} produces a list of bootstrapped data sets.
#' \code{plotBS} plots a phylogenetic tree with the with the bootstrap values
#' assigned to the (internal) edges.
#' 
#' It is possible that the bootstrap is performed in parallel, with help of the
#' multicore package. Unfortunately the multicore package does not work under
#' windows or with GUI interfaces ("aqua" on a mac). However it will speed up
#' nicely from the command line ("X11").
#' 
#' @param x an object of class \code{pml} or \code{phyDat}.
#' @param bs number of bootstrap samples.
#' @param trees return trees only (default) or whole \code{pml} objects.
#' @param multicore logical, whether models should estimated in parallel.
#' @param mc.cores The number of cores to use during bootstrap. Only supported
#' on UNIX-alike systems.
#' @param jumble logical, jumble the order of the sequences.
#' @param \dots further parameters used by \code{optim.pml} or
#' \code{plot.phylo}.
#' @param FUN the function to estimate the trees.
#' @param tree The tree on which edges the bootstrap values are plotted.
#' @param BStrees a list of trees (object of class "multiPhylo").
#' @param type the type of tree to plot, so far "cladogram", "phylogram" and
#' "unrooted" are supported.
#' @param bs.col color of bootstrap support labels.
#' @param bs.adj one or two numeric values specifying the horizontal and
#' vertical justification of the bootstrap labels.
#' @param p only plot support values higher than this percentage number
#' (default is 80).
#' @param frame a character string specifying the kind of frame to be printed
#' around the bootstrap values. This must be one of "none" (the default),
#' "rect" or "circle".
#' @return \code{bootstrap.pml} returns an object of class \code{multi.phylo}
#' or a list where each element is an object of class \code{pml}. \code{plotBS}
#' returns silently a tree, i.e. an object of class \code{phylo} with the
#' bootstrap values as node labels. The argument \code{BStrees} is optional and
#' if not supplied the tree with labels supplied in the \code{node.label} slot.
#' @author Klaus Schliep \email{klaus.schliep@@gmail.com}
#' @seealso \code{\link{optim.pml}}, \code{\link{pml}},
#' \code{\link{plot.phylo}},
#' \code{\link{nodelabels}},\code{\link{consensusNet}} and
#' \code{\link{SOWH.test}} for parametric bootstrap
#' @references Felsenstein J. (1985) Confidence limits on phylogenies. An
#' approach using the bootstrap. \emph{Evolution} \bold{39}, 783--791
#' 
#' Penny D. and Hendy M.D. (1985) Testing methods evolutionary tree
#' construction. \emph{Cladistics} \bold{1}, 266--278
#' 
#' Penny D. and Hendy M.D. (1986) Estimating the reliability of evolutionary
#' trees. \emph{Molecular Biology and Evolution} \bold{3}, 403--417
#' @keywords cluster
#' @examples
#' 
#' \dontrun{
#' data(Laurasiatherian)
#' dm <- dist.logDet(Laurasiatherian)
#' tree <- NJ(dm)
#' # NJ
#' set.seed(123)
#' NJtrees <- bootstrap.phyDat(Laurasiatherian, FUN=function(x)NJ(dist.logDet(x)), bs=100)
#' treeNJ <- plotBS(tree, NJtrees, "phylogram")
#' 
#' # Maximum likelihood
#' fit <- pml(tree, Laurasiatherian)
#' fit <- optim.pml(fit, rearrangements="NNI")
#' set.seed(123)
#' bs <- bootstrap.pml(fit, bs=100, optNni=TRUE)
#' treeBS <- plotBS(fit$tree,bs)
#' 
#' # Maximum parsimony
#' treeMP <- pratchet(Laurasiatherian)
#' treeMP <- acctran(treeMP, Laurasiatherian)
#' set.seed(123)
#' BStrees <- bootstrap.phyDat(Laurasiatherian, pratchet, bs = 100)
#' treeMP <- plotBS(treeMP, BStrees, "phylogram")
#' add.scale.bar()
#' 
#' # export tree with bootstrap values as node labels
#' # write.tree(treeBS)
#' }
#' 
#' @rdname bootstrap.pml
#' @export
bootstrap.pml <- function (x, bs = 100, trees = TRUE, multicore=FALSE, mc.cores = NULL, ...) 
{
    if(multicore && is.null(mc.cores)){
        mc.cores <- detectCores()
    }
    
    data = x$data
    weight = attr(data, "weight")
    v = rep(1:length(weight), weight)
    BS = vector("list", bs)
    for (i in 1:bs) BS[[i]] = tabulate(sample(v, replace = TRUE), 
                                       length(weight))
    pmlPar <- function(weights, fit, trees = TRUE, ...) {
        data = fit$data
        ind <- which(weights > 0)
        data <- getRows(data, ind)
        attr(data, "weight") <- weights[ind]
        fit = update(fit, data = data)
        fit = optim.pml(fit, ...)
        if (trees) {
            tree = fit$tree
            return(tree)
        }
        attr(fit, "data") = NULL
        fit
    }
    eval.success <- FALSE
    if (!eval.success & multicore) {
        res <- mclapply(BS, pmlPar, x, trees = trees, ..., mc.cores = mc.cores)
        eval.success <- TRUE
    }
    if (!eval.success) res <- lapply(BS, pmlPar, x, trees = trees, ...)
    if (trees) {
        class(res) = "multiPhylo"
        res = .compressTipLabel(res) # save memory
    }
    res
}


#' @rdname bootstrap.pml
#' @export
bootstrap.phyDat <- function (x, FUN, bs = 100, multicore=FALSE, mc.cores = NULL, jumble=TRUE, ...) 
{
    if(multicore && is.null(mc.cores)){
        mc.cores <- detectCores()
    }
    weight = attr(x, "weight")
    v = rep(1:length(weight), weight)
    BS = vector("list", bs)
    for(i in 1:bs)BS[[i]]=tabulate(sample(v, replace=TRUE),length(weight)) 
    if(jumble){
        J = vector("list", bs)
        l = length(x)
        for(i in 1:bs) J[[i]] = list(BS[[i]], sample(l))
    }
    fitPar <- function(weights, data, ...){     
        ind <- which(weights > 0)
        data <- getRows(data, ind)
        attr(data, "weight") <- weights[ind]
        FUN(data,...)        
    }
    fitParJumble <- function(J, data, ...){     
        ind <- which(J[[1]] > 0)
        data <- getRows(data, ind)
        attr(data, "weight") <- J[[1]][ind]
        data <- subset(data, J[[2]])
        FUN(data,...)        
    }
    if(multicore){
        if(jumble) res <- mclapply(J, fitPar, x, ..., mc.cores = mc.cores) 
        else res <- mclapply(BS, fitPar, x, ..., mc.cores = mc.cores) 
    }        
    else{
        if(jumble) res <- lapply(J, fitParJumble, x, ...) 
        else res <- lapply(BS, fitPar, x, ...)
    } 
    if(class(res[[1]]) == "phylo"){
        class(res) <- "multiPhylo"   
        res = .compressTipLabel(res) # save memory
    }
    res 
}


matchEdges <- function(tree1, tree2){
    bp1 <- bip(tree1)
    bp2 <- bip(tree2)
    l <- length(tree1$tip.label)
    fn <- function(x, y){
        if(x[1]==1)return(x)
        else return(y[-x])
    } 
    bp1[] = lapply(bp1, fn, 1:l)
    bp2[] = lapply(bp2, fn, 1:l)
    match(bp1, bp2)
}


checkLabels <- function(tree, tip){
    ind <- match(tip, tree$tip.label)
    if (any(is.na(ind)) | length(tree$tip.label) != length(tip))
        stop("tree has different labels")
    tree$tip.label <- tree$tip.label[ind]
    ind2 <- match(1:length(ind), tree$edge[, 2])
    tree$edge[ind2, 2] <- order(ind)
    tree
}


#' @rdname bootstrap.pml
#' @export
plotBS <- function (tree, BStrees, type = "unrooted", bs.col = "black", 
                    bs.adj = NULL, p=50, frame="none",...) 
{
    type <- match.arg(type, c("phylogram", "cladogram", "fan", 
                              "unrooted", "radial"))
    if (type == "phylogram" | type == "cladogram") {
        if (!is.rooted(tree) & !is.null(tree$edge.length)) 
            tree2 = midpoint(tree)
        else tree2=tree
        plot(tree2, type = type, ...)
    }
    else plot(tree, type = type, ...)
    
    if(hasArg(BStrees)){
        BStrees <- .uncompressTipLabel(BStrees) # check if needed
        if(any(is.rooted(BStrees)))BStrees <- unroot(BStrees)
#        if(any(unlist(lapply(BStrees, is.rooted)))){
#            BStrees <- lapply(BStrees, unroot)   
#        }
        x = prop.clades(tree, BStrees)
        x = round((x/length(BStrees)) * 100)
        tree$node.label = x
    }
    else{
        if(is.null(tree$node.label))stop("You need to supply BStrees or tree needs 
        needs BS-values as node.label")
        x <- tree$node.label
    }
    
    label = c(rep(0, length(tree$tip.label)), x)
    ind <- get("last_plot.phylo", envir = .PlotPhyloEnv)$edge[, 
                                                              2]
    if (type == "phylogram" | type == "cladogram") {
        root = getRoot(tree)
        label = c(rep(0, length(tree$tip.label)), x)
        label[root] = 0
        ind2 = matchEdges(tree2, tree)
        label = label[ind2]
        ind = which(label > p)
        #        browser()
        if (is.null(bs.adj)) 
            bs.adj = c(1, 1)
        if(length(ind)>0)nodelabels(text = label[ind], node = ind, frame = frame, 
                                    col = bs.col, adj = bs.adj, ...)
    }
    else {
        if (is.null(bs.adj)) 
            bs.adj = c(0.5, 0.5)
        ind2 = which(label[ind]>p)
        if(length(ind2>0))edgelabels(label[ind][ind2],ind2, frame = frame, col = bs.col, 
                                     adj = bs.adj, ...)
    }
    invisible(tree)
}




#' Maximum clade credibility tree
#' 
#' \code{maxCladeCred} computes the maximum clade credibility tree from a
#' sample of trees.
#' 
#' So far just the best tree is returned. No annotations or transformations of
#' edge length are performed.
#' 
#' If a list of partition is provided then the clade credibility is computed
#' for the trees in x.
#' 
#' @param x \code{x} is an object of class \code{multiPhylo} or \code{phylo}
#' @param tree logical indicating whether return the tree with the clade
#' credibility (default) or the clade credibility score for all trees.
#' @param rooted logical, if FALSE the tree with highest maximum bipartition
#' credibility is returned.
#' @param part a list of partitions as returned by \code{prop.part}
#' @return a tree (an object of class \code{phylo}) with the highest clade
#' credibility or a numeric vector of clade credibilities for each tree.
#' @author Klaus Schliep \email{klaus.schliep@@gmail.com}
#' @seealso \code{\link{consensus}}, \code{\link{consensusNet}},
#' \code{\link{prop.part}}
#' @keywords cluster
#' @examples
#' 
#' 
#' data(Laurasiatherian)
#' set.seed(42)
#' bs <- bootstrap.phyDat(Laurasiatherian, FUN = function(x)upgma(dist.hamming(x)), 
#'     bs=100)
#' class(bs) <- 'multiPhylo'
#' 
#' strict_consensus <- consensus(bs)
#' majority_consensus <- consensus(bs, p=.5)
#' max_clade_cred <- maxCladeCred(bs)
#' par(mfrow = c(1,3), mar = c(1,4,1,1))
#' plot(strict_consensus, main="Strict consensus tree")
#' plot(majority_consensus, main="Majority consensus tree")
#' plot(max_clade_cred, main="Maximum clade credibility tree")
#' 
#' # compute clade credibility for trees given a prop.part object
#' pp <- prop.part(bs)
#' tree <- rNNI(bs[[1]], 20)
#' maxCladeCred(c(tree, bs[[1]]), tree=FALSE, part = pp)
#' # first value likely be -Inf
#' 
#' @export maxCladeCred
maxCladeCred <- function(x, tree=TRUE, part=NULL, rooted=TRUE){
    if(inherits(x, "phylo")) x <- c(x)
    if (is.null(part)){ 
        if (!rooted) pp <- unroot(x) %>% prop.part
        else pp <- prop.part(x)
    }
    else pp <- part
    pplabel <- attr(pp, "labels")
    if(!rooted)pp <- oneWise(pp)
    x <- .uncompressTipLabel(x)
    class(x) <- NULL
    m <- max(attr(pp, "number"))
    nb <- log( attr(pp, "number") / m )
    l <-  length(x)
    res <- numeric(l)
    for(i in 1:l){
        tmp <- checkLabels(x[[i]], pplabel)
        if(!rooted)tmp <- unroot(tmp)
        ppi <- prop.part(tmp)  # trees[[i]]
        if(!rooted)ppi <- oneWise(ppi)
        indi <- fmatch(ppi, pp)
        if(any(is.na(indi))) res[i] <- -Inf
        else res[i] <- sum(nb[indi])
    }
    if(tree) {
        k <- which.max(res)
        tr <- x[[k]]
        attr(tr, "clade.credibility") <- res[k]
        return(tr)
    }    
    res
}


mcc <- maxCladeCred


cladeMatrix <- function(x, rooted=FALSE){
    if(!rooted) x <- unroot(x)
#    if(!rooted){
#        x <- .uncompressTipLabel(x)
#        x <- lapply(x, unroot) 
#        class(x) <- "multiPhylo"
#        x <- .compressTipLabel(x)
#    }    
    pp <- prop.part(x)
    pplabel <- attr(pp, "labels")
    if(!rooted)pp <- oneWise(pp)
    x <- .uncompressTipLabel(x)
    class(x) <- NULL
    nnodes <- sapply(x, Nnode)
    l <-  length(x)
    from <- cumsum(c(1, nnodes[-l]))
    to <- cumsum(nnodes)
    
    ivec <- integer(to[l])
    pvec <- c(0,to)
    
    res <- vector("list", l)
    k=1
    for(i in 1:l){
        ppi <- prop.part(x[[i]])  
        if(!rooted)ppi <- oneWise(ppi)
        indi <- sort(fmatch(ppi, pp))
        ivec[from[i]:to[i]] = indi
    }
    X <- sparseMatrix(i=ivec, p=pvec, dims=c(length(pp),l))
    list(X=X, prop.part=pp)
}


moving_average <- function(obj, window=50){
    fun <- function(x){
        cx <- c(0, cumsum(x))
        (cx[(window+1):length(cx)] - cx[1:(length(cx)-window)])/(window)
    }
    res <- apply(obj$X, 1, fun)
    rownames(res) <- c()
}
