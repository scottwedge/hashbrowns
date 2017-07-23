# distutils: language = c
# cython: cdivision = True
# cython: boundscheck = False
# cython: wraparound = False
# cython: profile = False

import numpy as np
import randomkit_wrap as randomkit

cdef void c_stable_non_gauss(npy_intp n, double alpha, double beta, double c, 
                             double mu, double * out, rk_state * state) nogil:
    cdef npy_intp i
    cdef double u, xi, inv_xi, inv_alpha, inv_alpha_minus_one
    cdef double zeta, w, t
    
    if alpha == 1.:
        if beta != 0.:
            for i in range(n):
                u = (rk_double(state) - 0.5) * M_PI
                w = -log(rk_double(state))
                out[i] = (M_PI_2 + beta * u) * tan(u)
                out[i] -= beta * log(M_PI_2 * w * cos(u) / (M_PI_2 + beta * u))
                out[i] *= M_2_PI
        else:
            for i in range(n):
                out[i] = tan((rk_double(state) - 0.5) * M_PI)
    else:
        inv_alpha = 1 / alpha
        inv_alpha_minus_one = inv_alpha - 1
        zeta = -beta * tan(M_PI_2 * alpha)
        xi = inv_alpha * atan(-zeta)
        t = (1 + zeta ** 2) ** (0.5 * inv_alpha)
        for i in range(n):
            u = (rk_double(state) - 0.5) * M_PI
            w = -log(rk_double(state))
            out[i] = t * sin(alpha * (u + xi))/(cos(u) ** inv_alpha)
            out[i] *= (cos(u - alpha * (u + xi)) / w) ** (inv_alpha_minus_one)    
    if c != 1.:
        for i in range(n):
            out[i] *= c
        if alpha == 1:
            t = M_2_PI * beta * c * log(c)
            for i in range(n):
                out[i] += t
    if mu != 0.:
        for i in range(n):
            out[i] += mu

def stable(double alpha, double beta=0, double c=1 , double mu=0, 
           object shape=None, RandomStateInterface rsi=None):
    cdef double scalar
    cdef double[::1] out 
    cdef rk_state * state
    
    if rsi is None:
        rsi = randomkit._rand_interface
    state = rsi.state_copy
    
    if alpha <= 0 or alpha > 2:
        raise ValueError("Stability parameter must be on (0,2].")
    if beta > 1 or beta < -1:
        raise ValueError("Skewness parameter must be on [-1,1].")
    if c <= 0:
        raise ValueError("Scale parameter must be greater than zero.")
    if alpha == 2:
        return np.random.normal(mu, c**2, shape=shape)
    
    with rsi.lock:
        rsi.retreive_state()
        
        if shape is None or shape == 1:
            c_stable_non_gauss(1, alpha, beta, c, mu, &scalar, state)
        else:
            n = np.prod(shape)
            out = np.empty(n, dtype=np.double)
            c_stable_non_gauss(n, alpha, beta, c, mu, &out[0], state)
        
        rsi.return_state()
    
    if shape is None or shape == 1:
        return scalar
    return np.asarray(out).reshape(shape)