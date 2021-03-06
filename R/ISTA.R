# {{{ proxGrad
#' @title Proximal gradient algorithm
#' @description Estimate parameters using a proximal gradient algorithm
#' 
#' @param start initial values for the parameters
#' @param proxOperator proximal operator corresponding to the penalization applied to the log likelihood
#' @param hessian second derivative of the likelihood given by lava. Only used to estimate the step parameter of the algorithm when step = NULL
#' @param gradient first derivative of the likelihood given by lava. 
#' @param objective likelihood given by lava. Used to adjust the step parameter when using backtracking
#' @param control settings for the proximal gradient algorithm. See lava.options.
#' 
#' @references 
#' Bech and Teboulle - 2009 A Fast Iterative Shrinkage-Thresholding Algorithm
#' Li 2015 - Accelerated Proximal Gradient Methods for Nonconvex Programming
#' Simon 2013 - A sparse group Lasso
proxGrad <- function(start, proxOperator,
                     hessian, gradient, objective,
                     control = lava.options()$proxGrad){

    # {{{ import control
    method <- control$method
    iter.max <- control$iter.max
    step <- control$step
    BT.n <- control$BT.n
    BT.eta <- control$BT.eta
    abs.tol <- control$abs.tol
    rel.tol <- control$rel.tol
    force.descent <- control$force.descent
    export.iter <- control$export.iter
    trace <- control$trace
    # }}}
    
    stepMax <- step 
  
    #### Check method
    valid.method <- c("ISTA","FISTA_Beck","FISTA_Vand","mFISTA_Vand")
    if(method %in% valid.method == FALSE){
        stop(method," is not a valid method for the proximal gradient algorithm \n",
             "available methods: ", paste(valid.method, collapse = " "),"\n")
    }
  
    ## preparation
    fct_errorLv <- function(e){warning("unable to compute the value of the likelihood - return Inf \n");return(Inf)}
  
    ## initialisation
    x_k <- start 
  
    obj.x_k <- tryCatch(objective(x_k), error = fct_errorLv)
    if(is.na(obj.x_k)){obj.x_k <- Inf}
    grad.x_k <- try(gradient(x_k))
    obj.x_kp1 <- relDiff <- absDiff <- stepBT <- NA
  
    t_k <- t_kp1 <- if(method %in% c("FISTA_Beck")){1}else{NA}
    y_k <- if(method %in% c("FISTA_Beck","FISTA_Vand","mFISTA_Vand")){x_k}else{NA} 
    obj.y_k <- if(method %in% c("FISTA_Beck","FISTA_Vand","mFISTA_Vand")){obj.x_k}else{NA} 
    grad.y_k <- if(method %in% c("FISTA_Beck","FISTA_Vand","mFISTA_Vand")){grad.x_k}else{NA} 
  
    if("function" %in% class(hessian)){
        maxEigen <- 1/rARPACK::eigs_sym(hessian(x_k),k=1, which = "LM", opts = list(retvec = FALSE))$values
        step <-  abs(maxEigen)
    }
  
    test.cv <- FALSE
    iter <- 0
    iterAll <- 0

    if(trace>0){cat("Loop proximal gradient \n")}
    if(trace>1){cat("stepBT"," ","iter_back", " ", "max(abs(x_kp1 - x_k))"," ","obj.x_kp1 - obj.x_k","\n")}
    if(export.iter){details.cv <- NULL}
  
    ## loop
    while(test.cv == FALSE && iter < iter.max){
        iter <- iter + 1 
    
        iter_back <- 0
        diff_back <- 1
        obj.x_kp1 <- +Inf

        
        while( (iter_back < BT.n) && (is.infinite(obj.x_kp1) || diff_back > 0) ){ # Backtracking

            stepBT <- step*BT.eta^iter_back
            iterAll <- iterAll + 1

            if(method == "ISTA"){
                res <- ISTA(x_k = x_k, obj.x_k = obj.x_k, grad.x_k = grad.x_k, 
                            proxOperator = proxOperator, step = stepBT)
            }else if(method %in% c("FISTA_Beck","FISTA_Vand","mFISTA_Vand")){
                res <- ISTA(x_k = y_k, obj.x_k = obj.y_k, grad.x_k = grad.y_k, 
                            proxOperator = proxOperator, step = stepBT)
            }
      
            obj.x_kp1 <- tryCatch(objective(res$x_kp1), error = fct_errorLv) 
            if(is.na(obj.x_kp1)){obj.x_kp1 <- Inf}
      
            if(force.descent == TRUE){
                diff_back <- obj.x_kp1 - obj.x_k
            }else{
                diff_back <- obj.x_kp1 - res$Q
            }
      
            iter_back <- iter_back + 1
      
            # cat("obj.x_kp1:",obj.x_kp1," | obj.x_k:",obj.x_k, " | res$Q:",res$Q,"\n")
        }

        if(method == "mFISTA_Vand"){
            res$u <- res$x_kp1
            if(obj.x_kp1>obj.x_k){
                res$x_kp1 <- x_k
                obj.x_kp1 <- obj.x_k
                res$cv <- TRUE
            }
        }
    
        if(force.descent && obj.x_kp1 > obj.x_k){break}
    
        absDiff <- abs(obj.x_kp1 - obj.x_k) < abs.tol
        relDiff <- abs(obj.x_kp1 - obj.x_k)/abs(obj.x_kp1) < rel.tol
        test.cv <- (absDiff + relDiff > 0)
        if("cv" %in% names(res)){test.cv <- res$cv}
    
    
        ## update
        if(method %in% c("FISTA_Beck","FISTA_Vand","mFISTA_Vand")){
      
            if(method == "FISTA_Beck"){
                t_k <- t_kp1
                t_kp1 <- (1 + sqrt(1 + 4 * t_k^2)) / 2
                y_k <- res$x_kp1 + (t_k-1)/t_kp1 * (res$x_kp1 - x_k) 
            }else if(method == "FISTA_Vand"){
                y_k <- res$x_kp1 + (iter-2)/(iter+1) * (res$x_kp1 - x_k) 
            }else if(method == "mFISTA_Vand"){
                theta_kp1 <- 2/(iter+1)
                v_kp1 <- x_k + 1/theta_kp1 * (res$u - x_k)
                y_k <- (1 - theta_kp1) * res$x_kp1 + theta_kp1 * v_kp1
            }
      
            obj.y_k <- tryCatch(objective(y_k), error = fct_errorLv)
            if(is.na(obj.y_k)){obj.y_k <- Inf}
            grad.y_k <- try(gradient(y_k))
      
        }
    
        ## display
        if(trace>1){cat(iter,"|",stepBT," ",iter_back, " ", max(abs(res$x_kp1 - x_k))," ",obj.x_kp1 - obj.x_k,"\n")}
    
        ## update2
        if(export.iter){
            details.cv <- rbind(details.cv,
                                c(iteration = iter, stepBT = stepBT, iter_back = iter_back, adiff_param = max(abs(res$x_kp1 - x_k)), obj = obj.x_kp1, diff_obj = obj.x_kp1 - obj.x_k))
        }
        step <- min(stepMax, stepBT/sqrt(BT.eta))# stepBT
        x_k <- res$x_kp1
        obj.x_k <- obj.x_kp1
        grad.x_k <- try(gradient(res$x_kp1))
    
    
    }
    if(trace>0){cat("End loop proximal gradient \n")}
  
    ## export
    message <- if(test.cv){"Sucessful convergence \n"
               }else{
                   paste("max absolute/relative difference: ",max(abs(obj.x_kp1 - obj.x_k)),"/",max(abs(obj.x_kp1 - obj.x_k)/abs(obj.x_kp1))," for parameter ",which.max(absDiff),"/",which.max(relDiff),"\n")
               }
  
    return(list(par = x_k,
                step = stepBT,
                convergence = as.numeric(test.cv==FALSE),
                iterations = iter,
                iterationsAll = iterAll,
                evaluations = c("function" = 0, "gradient" = iter),
                message = message,
                algorithm = "proximal gradient",
                method = method,
                details.cv = if(export.iter){details.cv}else{NULL}
                ))
}
# }}}

# {{{ ISTA
ISTA <- function(x_k, obj.x_k, grad.x_k,
                 proxOperator, step){

    ## Step
    x_kp1 <- proxOperator(x = x_k - step * grad.x_k, step = step)
    
    ## Upper bound for backtracking
    Q <- Qbound(diff.xy = x_kp1 - x_k, obj.y = obj.x_k, grad.y = grad.x_k, L = 1/step)
  
    return(list(x_kp1 = x_kp1,
                Q = Q))
}
# }}}


#' @title Estimate an upper bound of obj.x
#' @description Estimate an upper bound of obj.x
Qbound <- function(diff.xy, obj.y, grad.y, L){
  
  return(obj.y + crossprod(diff.xy, grad.y) + L/2 * crossprod(diff.xy))
  
}
