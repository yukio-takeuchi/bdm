
#{{{ fit functions
setGeneric("fit", function(.Object,data, ...) standardGeneric("fit"))
#{{ fit bdm model to data
setMethod("fit",signature=c("bdm","list"),function(.Object,data,init,chains,iter,warmup,thin,run,method="MCMC", ...) {
  
  if(missing(data)) 
    stop('No data object supplied\n')
  
  # number of data indices
  # nix <- ifelse(length(dim(data$index))>1,dim(data$index)[2],1)
  
  if(!missing(run))
    .Object@run <- as.character(run) 
  
  # check data
  if(any(data$harvest<0) | any(is.na(data$harvest))) 
    stop('missing catch (harvest) data is not allowed\n')
  .Object@data <- lapply(data,function(x) x)
    
  # set initialisation function
  if(.Object@default_model) {
    
    # default initialisation function
    init.func <- function() { 
      
      b    <- init.r/exp(init.logK)
      r    <- init.r * rlnorm(1,log(1)-0.04/2,0.2)
      logK <- max(min(log(r/b),30),3)
      
      x    <- .getx(r,logK,.Object)
      
      init.values <- list(logK   = logK,
                          r      = r,
                          x      = x)
      
      init.values
    }     
    
    if(missing(init)) {
      
      init.r    <- .getr(.Object)
      init.logK <- .getlogK(.Object)
  	
    } else {
      if(is.list(init)) {
    		if(!is.null(init$logK)) init.logK <- init$logK else init.logK <- .getlogK(.Object)
    		if(!is.null(init$r))    init.r    <- init$r    else init.r    <- .getr(.Object)
      }
      if(is.function(init)) {
        init.func <- init
      }
    }
  } else {
    # non-default settings
    if(missing(init))
      stop('must supply initialisation function for non-default model\n')
  	if(is.function(init)) {
  		init.func <- init
  	} else stop('initialisation function must be supplied\n')
  }
    
  # update .Object
  .Object@init.func <- init.func
  
  # sampling dimensions
  if(!missing(chains))    .Object@chains <- chains
  if(!missing(iter))      .Object@iter   <- iter
  if(!missing(thin))      .Object@thin   <- thin
  if(!missing(warmup))    .Object@warmup <- warmup else .Object@warmup <- floor(.Object@iter/2/.Object@thin)
  
  # number of posterior samples
  .Object@nsamples <- ((.Object@iter - .Object@warmup) * .Object@chains)/.Object@thin

  if(method=='MCMC') {
    
    # initiate mcmc-sampling
    cat('MCMC sampling\n')
    stanfit_object <- suppressWarnings(sampling(.Object,data=.Object@data,init=.Object@init.func,iter=.Object@iter,chains=.Object@chains,warmup=.Object@warmup,thin=.Object@thin, ...))
    
    # extract traces
    .Object@trace_array <- extract(stanfit_object,permuted=FALSE,inc_warmup=TRUE)
    .Object@trace       <- extract(stanfit_object)
    
    # record initial values for each chain
    .Object@init.values <- stanfit_object@inits
  }
  if(method=='MPD') {
    
    # initiate mpd fit
    cat('MPD optimisation\n')
    .Object@mpd <- optimizing(.Object,data=.Object@data,init=.Object@init.func, ...)
  }
  
  .Object
})
#{ initial value functions for r, logK and x
.getr <- function(.Object) {
  
  # extract r from model_code
  
  m <- regexpr('r.?~.?lognormal\\(.+?\\)',.Object@model_code)
  x <- regmatches(.Object@model_code,m)
  
  m1 <- regexpr('\\(.+?\\,',x)
  m1 <- m1 + 1
  attributes(m1)$match.length <- attributes(m1)$match.length - 2
  x1 <- regmatches(x,m1)
  
  m2 <- regexpr('\\,.+?\\)',x)
  m2 <- m2 + 1
  attributes(m2)$match.length <- attributes(m2)$match.length - 2
  x2 <- regmatches(x,m2)
  
  mu <- as.numeric(x1)
  sigma <- as.numeric(x2)
  
  init.r <- exp(mu+sigma^2/2)
  
  init.r
}
.getlogK <- function(.Object) {
  
  # get logK through grid search
  # assuming a logistic production model
  
  rr <- .getr(.Object)
  
  ii <- .Object@data$index
  cc <- .Object@data$harvest
  tt <- length(cc)
  bm <- numeric(tt)
  
  ll <- 1e-4
  
  # least-squares objective
  # function
  obj <- function(logK) {
  
    bm[1] <- 1
    for(t in 1:tt) 
      bm[t+1] <- max(bm[t] + rr*bm[t]*(1 - bm[t]) - cc[t]/exp(logK),ll)
    bm <- bm[-length(bm)]
  
    q <- mean(apply(ii,2,function(x) exp(mean(log(x[x>0]/bm[x>0])))))
  
    sum(apply(ii,2,function(x) sum(log(x[x>0]/(q*bm[x>0]))^2))) + ifelse(any(bm==ll),Inf,0) + ifelse(bm[tt]>0.99,Inf,0)
  }
  
  np <- 1000
  logK.llk <- numeric(np)
  logK.seq <- seq(3,30,length=np)
  for(i in 1:np) 
    logK.llk[i] <- obj(logK.seq[i])
  
  init.logK <- logK.seq[which.min(logK.llk)]
  
  init.logK
}
.getx <- function(r,logK,.Object) {

  cc <- .Object@data$harvest
  tt <- length(cc)
  bm <- numeric(tt)
  
  ll <- 1e-4
  
  bm[1] <- 1
  for(t in 1:tt) 
    bm[t+1] <- max(bm[t] + r*bm[t]*(1 - bm[t]) - cc[t]/exp(logK),ll)
  bm <- bm[-length(bm)]
  
  init.x <- bm
  
  init.x
}
#}
#}}
#{{ fit log-normal distribution to monte-carlo r values
setMethod("fit",signature=c("rprior","missing"),function(.Object, ...) { 
  .fitr(.Object)
})
#{ fitting function
.fitr <- function(.Object) {
  
  x <- .Object@.Data
  if(!length(x)>2) stop('need >2 r values')
  
  # transform to normal
  y <- log(x)
  
  # estimate parameters of
  # normal distribution log(x)
  mu    <- mean(y)
  sigma <- sd(y)
  sigma2 <- sigma^2
  
  # estimate parameters of
  # log-normal distribution
  theta <- exp(mu + sigma2/2)
  nu <- exp(2*mu + sigma2)*(exp(sigma2) - 1)
  cv <- sqrt(exp(sigma2) - 1)
  
  # assign and return
  .Object@lognormal.par <- list('E[log(x)]'=mu,'SD[log(x)]'=sigma,'E[x]'=theta,'VAR[x]'=nu,'CV[x]'=cv)
  return(.Object)
  
}
#}
#}}
#}}}


