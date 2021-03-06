
#{{{ rcalc()
# calculate r from numerical solution to Euler-Lotka equation
# using rdat class as input
setGeneric("rcalc", function(.Object, ...) standardGeneric("rcalc"))
setMethod("rcalc",signature="rdat",function(.Object, ...) {
  
  n <- .Object@iter
  prior <- new('rprior',n)
  
  for(i in 1:n)
    prior[i] <- .rcalc(.iter(.Object,i))
  
  return(prior)
  
})

.rcalc <- function(.Object) {
  
  # survivorship
  l <- .Object@lhdat[['survivorship']]
  
  # spawning biomass per recruit
  SBPR  <- sum(.Object@lhdat[['survivorship']] * .Object@lhdat[['mass']] * .Object@lhdat[['maturity']])
  #cat('SBPR:',SBPR,'\n')
  
  # recruits per unit of spawning biomass
  if(.Object@sr=='BH') {
    alpha <- (4 * .Object@lhdat[['h']])/(SBPR * (1 - .Object@lhdat[['h']]))
  } else if(.Object@sr=='RK') {
    alpha <- .Object@lhdat[['h']]^1.25 / (SBPR * exp(log(0.2)/0.8))
  } else stop("sr must be either 'BH' or 'RK'\n")
  #cat('alpha:',alpha,'\n')
  
  # female fecundity at age 
  # (recruited mature biomass per unit of spawning biomass)
  m <- alpha * .Object@lhdat[['mass']] * .Object@lhdat[['maturity']]
  
  # minimise Euler-Lotka equation
  obj <- function(r) sum(exp(-r * 1:.Object@amax) * l * m) - 1
  r <- uniroot(obj,interval=c(0,10))$root
  
  # return intrinsic growth rate
  return(r)
  
}

.iter <- function(.Object,i) {
  x <- new('rdat.iter',amax = .Object@amax,sr=list(type=.Object@sr))
  x@lhdat <- lapply(.Object@lhdat,function(x) x[,i]) 
  return(x)
}
#}}}
