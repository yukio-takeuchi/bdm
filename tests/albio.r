
# INDIAN OCEAN ALBACORE

##############
# START HERE #
##############

rm(list=ls())

# install and load bdm package
#install.packages("bdm",contriburl="file://niwa.local/Groups/wellington/niwafisheries/R/",type="win.binary",repos=NULL)
install.packages("C:/PROJECTS/SOFTWARE/OpenSource/bdm_1.0.zip", repos = NULL)

library(bdm)
library(kobe)
library(plyr)
library(ggplot2)

# load data
data(albio)
dat <- edat(harvest=albio$catch,index=albio$cpue,year=rownames(albio))

# initialise object
mdl <- bdm()

# update data and priors using values from Meyer and Millar (CJFAS 1999)
# error terms
sigmao(dat) <- sqrt(0.0086/(1.71 - 1))
sigmap(dat) <- sqrt(0.0102/(3.79 - 1))
# intrinsic growth rate
mdl <- update_bdm(mdl,list(a=-1.38,b=0.51,par='r'))

# inspect code
mdl

# compile
mdl <- compile_bdm(mdl)

# mcmc fit
mdl <- fit(mdl,dat,iter=5000,thin=10,chain=2)
traceplot(mdl,pars=c('r','logK'))
histplot(mdl,pars=c('r','logK'))

# kobe plot
assmt <- as.kobe(mdl,what=c('sims','trks','pts'))
kobePhase(ylim=c(0,max(2,assmt[['pts']]$harvest))) + 
  geom_path(aes(stock,harvest),data=subset(assmt[['trks']],Percentile=='50%'),col="blue",size=1) + 
  geom_path(aes(x,y,group=level),colour="blue",data=kobeProb(assmt[['pts']]$stock,assmt[['pts']]$harvest,prob=c(0.75,.5,.25))) +
  geom_point(aes(stock,harvest), data=subset(assmt[['trks']],Percentile=='50%' & year==unique(assmt[['pts']]$year)),col="blue",size=4)

# projections
harvest.time <- 30

harvest.scenarios <- c(10,15,20)
mdl.projections <- project(mdl,harvest.scenarios,harvest.time,harvest_rate=FALSE)

harvest.scenarios <- c(0.10,0.15,0.20)
mdl.projections <- project(mdl,harvest.scenarios,harvest.time,harvest_rate=TRUE)

prj <- as.kobe(mdl,mdl.projections,what=c('sims','trks','pts'))
kobePhase(subset(prj$sims,year==max(prj$sims$year))) +
  geom_point(aes(stock,harvest,group=projection_value,col=projection_value))

#######
# END #
#######


