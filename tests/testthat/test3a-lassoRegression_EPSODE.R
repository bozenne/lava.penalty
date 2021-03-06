### test-lassoRegression_EPSODE.R --- 
#----------------------------------------------------------------------
## author: Brice Ozenne
## created: mar 16 2017 (09:18) 
## Version: 
## last-updated: apr  3 2017 (19:11) 
##           By: Brice Ozenne
##     Update #: 35
#----------------------------------------------------------------------
## 
### Commentary: 
##
## BEFORE RUNNING THE FILE:
## library(butils.base) ; package.source("lavaPenalty") ;
## path <- file.path(butils.base::path_gitHub(),"lavaPenalty","tests")
## source(file.path(path,"FCT.R"))
### Change Log:
#----------------------------------------------------------------------
## 
### Code:

library(lavaPenalty)
library(penalized)
library(testthat)

#### > settings ####
test.tolerance <- 1e-3
test.scale <- NULL
lavaPenalty.options(trace = FALSE, type = "lava")
lavaPenalty.options(trace = FALSE, type = "proxGrad")
lambda2 <- 5

context("#### EPSODE algorithm #### \n")

# {{{ simulation and LVM
# parametrisation
set.seed(10)
n <- 500
formula.lvm <- as.formula(paste0("Y~",paste(paste0("X",1:5), collapse = "+")))
lvm.modelSim <- lvm()
regression(lvm.modelSim, formula.lvm) <-   as.list( c(rep(0,2),1:3) ) # as.list( c(rep(0,2),0.25,0.5,0.75) ) # 
distribution(lvm.modelSim, ~Y) <- normal.lvm(sd = 2)

# simulation
df.data <- sim(lvm.modelSim,n)
df.data <- as.data.frame(scale(df.data))

# estimation
lvm.model <- lvm(formula.lvm)
elvm.model <- estimate(lvm.model, df.data)

# path
penalized.PathL1 <- penalized(Y ~  ., data = df.data, steps = "Park", lambda2 = lambda2, trace = FALSE)
seq_lambda1 <- unlist(lapply(penalized.PathL1, function(x){x@lambda1}))
seq_lambda1Sigma <- unlist(lapply(penalized.PathL1, function(x){x@lambda1/x@nuisance$sigma2}))
n.lambda <- length(seq_lambda1)

plvm.model <- penalize(lvm.model, Vridge = TRUE)
# }}}

# lasso# [1] 361.069657 361.033550 229.350080 129.031487 129.018584   6.985620   5.673622   0.000000
# EN   # [1] 361.069657 361.033550 229.350082 129.094503   7.080412   7.010819   7.010118   5.348758   5.346142   0.000000
# {{{ Lars
test_that("LARS (lasso)", {

    ## backward
    PathLars <- estimate(plvm.model,  data = df.data, lambda2 = lambda2,
                         control = list(constrain = FALSE),
                         regularizationPath = TRUE)
    
    tableLARS <- getPath(PathLars, increasing = FALSE)
    # plot(PathLars)
   
    for(iPath in 2:NROW(tableLARS)){ # iPath <- 5
        index.penalized <- which.min(abs(tableLARS[iPath,lambda1.abs]-seq_lambda1))
        coef.expected <- coef2.penalized(penalized.PathL1[[index.penalized]], name.response = "Y")[names(coef(elvm.model))]
        coef.LARS <- tableLARS[iPath,names(coef.expected),with = FALSE]

        expect_equal(as.double(tableLARS[iPath,lambda1.abs]),
                     expected=as.double(seq_lambda1[index.penalized]),
                     tolerance=test.tolerance, scale=test.scale)    
        expect_equal(as.double(coef.expected), expected=as.double(coef.LARS), tolerance=test.tolerance, scale=test.scale)    
    }

    ## forward
    PathLars.f <- estimate(plvm.model,  data = df.data, lambda2 = lambda2,
                           control = list(constrain = FALSE),
                           control.EPSODE = list(increasing = TRUE),
                           regularizationPath = TRUE)
    #PathLars.f$regularizationPath$path 
    #PathLars$regularizationPath$path
  
})
# }}}

# {{{ EPSODE
test_that("EPSODE (lasso)", {

    
    ## at fixed sigma
    PathEPSODE <- estimate(plvm.model,  data = df.data, fit = NULL, lambda2 = lambda2,
                           control = list(constrain = FALSE),
                           equivariance = TRUE,
                           control.EPSODE = list(resolution_lambda1 = c(0.5,0.001),
                                                 stopParam = 3),
                           regularizationPath = TRUE)
                              
    tableEPSODE <- getPath(PathEPSODE, increasing = FALSE, only.breakpoints = TRUE)
    
   for(iPath in 2:NROW(tableEPSODE)){ # iPath <- 1
       index.penalized <- which.min(abs(tableEPSODE[iPath,lambda1.abs]-seq_lambda1))
       coef.expected <- coef2.penalized(penalized.PathL1[[index.penalized]], name.response = "Y")[names(coef(elvm.model))]
       coef.EPSODE <- tableEPSODE[iPath,names(coef.expected),with = FALSE]

       expect_equal(as.double(tableEPSODE[iPath,lambda1.abs]),
                    expected=as.double(seq_lambda1[index.penalized]),
                    tolerance=0.1, scale=test.scale)    
       expect_equal(as.double(coef.expected), expected=as.double(coef.EPSODE),
                    tolerance=0.01, scale=test.scale)    
   }

   PathEPSODE.f <- estimate(plvm.model,  data = df.data, fit = NULL, lambda2 = lambda2,
                            control = list(constrain = FALSE),
                            equivariance = TRUE,
                            control.EPSODE = list(resolution_lambda1 = c(0.5,0.001),
                                                  stopParam = 3, increasing = TRUE, exportAllPath = TRUE),
                            regularizationPath = TRUE)
  
})

# }}}

# {{{ EPSODE heteroscedastic errors

set.seed(10)
n <- 500
mSim <- lvm()
regression(mSim, Y ~ X1 + X2 + X3 + X4 + X5) <-   as.list( c(rep(0,2),1:3) ) # as.list( c(rep(0,2),0.25,0.5,0.75) ) # 
parameter(mSim, start = 1) <- ~sigma0
distribution(mSim, ~group) <- binomial.lvm(p=0.5,size=2)
constrain(mSim,sigma~sigma0+group) <- function(x) x[,1]*(1+x[,2])

df <- sim(mSim, n)

## library(nlme)
## eGLS <- gls(Y ~ X1 + X2 + X3 + X4 + X5,
##             weights = varIdent(form=~1|group),
##             data = df)
## summary(eGLS)


mC <- lvm()
regression(mC, Y ~ X1 + X2 + X3 + X4 + X5) <- as.list(paste0("beta",1:5))
eCGroup <- estimate(list(mC,mC,mC), split(df, df$group) )

m <- lvm(Y ~ X1 + X2 + X3 + X4 + X5)
eGroup <- estimate(list(m,m,m), split(df, df$group) )

m <- lvm(Y ~ X1 + X2 + X3 + X4 + X5)
eGroup <- estimate(list(m,m,m), split(df, df$group) )

debug(lava:::estimate.lvmlist)

eGroup

mCC1 <- lvm(Y[mu:5] ~ X1 + X2 + X3 + X4 + X5)
eCC1Group <- estimate(list(mCC1,m,m), split(df, df$group) )
coef(eGroup)
coef(eCC1Group)

plot(m, labels =TRUE)
# }}}

test <- FALSE
if(test){

    # parametrisation
    set.seed(10)
    n <- 5e2
    lvm.modelSim <- lvm(Y1~eta+0*X1+0.1*X2,
                        Y2~eta+0*X3+0.5*X4,
                        Y3~eta+0*X5+1*X6)
    latent(lvm.modelSim) <- ~eta
    
    # simulation
    df.data <- sim(lvm.modelSim,n)
    index.latent <- which(names(df.data) %in% latent(lvm.modelSim) == FALSE)
    df.data <- as.data.frame(scale(df.data))[,index.latent]
    head(df.data)
    # estimation

    lvm.model <- lvm(Y1~eta+X1+X2,Y2~eta+X3+X4,Y3~eta+X5+X6)
    latent(lvm.model) <- ~eta
    elvm.model <- estimate(lvm.model, df.data)

    
    plvm.model <- penalize(lvm.model,
                           value = c("Y1~X1","Y1~X2",
                                     "Y2~X3","Y2~X4",
                                     "Y3~X5","Y3~X6"),
                           Vridge = FALSE)

    testEPSODE <- estimate(plvm.model,  data = df.data, regularizationPath = TRUE,
                           fit = NULL, control = list(constrain = TRUE),
                           equivariance = FALSE)
    plot(testEPSODE, coef = c("Y2~~Y2"))
    plot(testEPSODE)

        initVar_link("eta")
    seq_lambda <- c(11.10,11.15,
                    11.45,11.50,
                    48.00,48.05)
    sapply(seq_lambda,)
    run1()
    getPath(PathEPSODE)
    plot(PathEPSODE, lambda = "lambda1", coef = "penalized")

    coef(elvm.model)


    testL1 <- estimate(plvm.model,  data = df.data, lambda1 = 11.1,
                       fit = NULL, control = list(constrain = TRUE),
                       equivariance = FALSE)
    # 11.1 X3
    # 11.45 X1
    # 48 X5
    testL1

    plot(testL1)
    
    testL1 <- estimate(plvm.model,  data = df.data,
                       control = list(constrain = TRUE),
                       regularizationPath = cbind(lambda1 = seq_lambda),
                       equivariance = FALSE)



## linear model
    mSim <- lvm(Y[1:2] ~ X1 + X2 + X3)
    d <- sim(mSim, 1e3)

    eTRUE <- estimate(lvm(Y ~ X1 + X2 + X3), data = d)

    m <- lvm(Y[mu:1] ~ X1 + X2 + X3)    
    eConstrain <- estimate(m, data = d)

    name.coef <- coefReg(mTRUE, value = TRUE)
    coef(eTRUE)[name.coef] - coef(eConstrain)[name.coef]

## LVM
    mSim <- lvm(Y1[1:2] ~ X1 + X2 + X3 + eta,
                Y2[0:2] ~ X1 + X2 + X3 + eta,
                Y3[2:2] ~ X1 + X2 + X3 + eta)
    regression(mSim) <- eta ~ group
    d <- sim(mSim, 1e3)

    mTRUE <- lvm(Y1 ~ X1 + X2 + X3,
                 Y2 ~ X1 + X2 + X3,
                 Y3 ~ X1 + X2 + X3)
    eTRUE <- estimate(mTRUE, data = d)

    mConstrain <- lvm(Y1[mu1:1] ~ X1 + X2 + X3,
                      Y2[mu2:1] ~ X1 + X2 + X3,
                      Y3[mu3:1] ~ X1 + X2 + X3)
    eConstrain <- estimate(mConstrain, data = d)

    name.coef <- names(coef(eConstrain))
    coef(eTRUE)[name.coef] - coef(eConstrain)[name.coef]


    mTRUE <- lvm(Y1 ~ X1 + X2 + X3 + eta,
                 Y2 ~ X1 + X2 + X3 + eta,
                 Y3 ~ X1 + X2 + X3 + eta)
    regression(mTRUE) <- eta ~ group
    latent(mTRUE) <- ~eta
    eTRUE <- estimate(mTRUE, data = d)

    mConstrain <- lvm(Y1[mu1:1] ~ X1 + X2 + X3 + 1*eta,
                      Y2[mu2:1] ~ X1 + X2 + X3 + 1*eta,
                      Y3[mu3:1] ~ X1 + X2 + X3 + 1*eta)
    regression(mConstrain) <- eta ~ group
    latent(mConstrain) <- ~eta
    eConstrain <- estimate(mConstrain, data = d)

    name.coef <- names(coef(eConstrain))
    coef(eTRUE)[name.coef] - coef(eConstrain)[name.coef]
}

#----------------------------------------------------------------------
### test-lassoRegression_EPSODE.R ends here
