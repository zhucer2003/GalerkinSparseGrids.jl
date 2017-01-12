# Generates the coefficients for a traveling wave 
# with n nodes on the interior of our D-dimensional hypercube

function cos_coeffs(k::Int, n::Int, m::Array{Int,1}; phase = 0.0, A = 1.0)
    D = length(m)
    wavenumber = 2*pi*m
    
    # Begin with writing cos(\sum_i k_i x_i) as a sum of products
    # of sines/cosines of individual k_j x_j
    sines = [i==1?x->sin(wavenumber[i]*x[1]+phase):x->sin(wavenumber[i]*x[1]) for i in 1:D]
    cosines = [i==1?x->cos(wavenumber[i]*x[1]+phase):x->cos(wavenumber[i]*x[1]) for i in 1:D]
    
    
    sine_coeffs = [vhier_coefficients_DG(k, sines[i], (n+1,)) for i in 1:D]
    cosine_coeffs = [vhier_coefficients_DG(k, cosines[i], (n+1,)) for i in 1:D]

    sine_dicts = [full_V2D(k, sine_coeffs[i], (n+1,)) for i in 1:D]
    cosine_dicts = [full_V2D(k, cosine_coeffs[i], (n+1,)) for i in 1:D]
    
    ansVect = zeros(sparse_size(k,n,D))

    for SCs in CartesianRange(ntuple(q->2, D))
        num_sines = sum([SCs[i]-1 for i in 1:D])
        if num_sines % 2 == 1
            continue 
        end
        sign = num_sines%4==0?1:-1
        # may want to add an if-statement for if any n[i] == 0
        
        coeffArray = [SCs[i]==1?cosine_dicts[i]:sine_dicts[i] for i in 1:D]
        productDict = tensor_construct_sparse(k, n, D, coeffArray)
        productVect = sparse_D2V(k, productDict, n)
        
        ansVect += sign * productVect
    end
        
    return A*ansVect
end

function sin_coeffs(k::Int, n::Int, m::Array{Int,1}; phase = 0.0, A = 1.0)
    return cos_coeffs(k, n, m; phase = - pi/2 + phase, A = A)
end

function travelling_wave(k::Int, n::Int, m::Array{Int,1}; phase = 0.0, A = 1.0)
    wavenumber = 2*pi*m
    frequency = sqrt(vecdot(wavenumber,wavenumber))
    
    u0 = x -> A*cos(vecdot(wavenumber,x)+phase)
    v0 = x -> A*frequency*sin(vecdot(k,x)+phase)
    
    u0_coeffs = cos_coeffs(k, n, m; phase = phase, A = A) 
    
    v0_coeffs = sin_coeffs(k, n, m; phase = phase, A = A*frequency) 
    
    return (u0_coeffs, v0_coeffs, u0, v0)
    
end


function travelling_wave_equation45(k::Int,n::Int, m::Array{Int,1}, time0::Real, time1::Real; phase = 0.0, A = 1.0)
    D = length(m)
    f0coeffs, v0coeffs = travelling_wave(k, n, m; phase = phase, A = A)
    srefVD = sparse_referenceV2D(k, n, D);
    srefDV = sparse_referenceD2V(k, n, D);
    
    len = length(f0coeffs)
    laplac=spzeros(len, len)
    for i in 1:D
        D_op = sparse_D_matrix(i,k,n,srefVD, srefDV)

        laplac += *(D_op,D_op)
    end
    RHS = spzeros(2*len, 2*len)
    
    for i in len+1:2*len
        for j in 1:len
            RHS[i,j] = laplac[i-len,j]
            RHS[j,j+len] = 1.0
        end
    end
    y0 = Array{Float64}([i<=len?f0coeffs[i]:v0coeffs[i-len] for i in 1:2*len])
    soln=ode45((t,x)->*(RHS,x), y0, [time0,time1])
    return soln
    
end

function travelling_wave_equation78(k::Int,n::Int, m::Array{Int,1}, time0::Real, time1::Real; phase = 0.0, A = 1.0)
    D = length(m)
    f0coeffs, v0coeffs = travelling_wave(k, n, m; phase = phase, A = A)
    srefVD = sparse_referenceV2D(k, n, D);
    srefDV = sparse_referenceD2V(k, n, D);
    
    len = length(f0coeffs)
    laplac=spzeros(len, len)
    for i in 1:D
        D_op = sparse_D_matrix(i,k,n,srefVD, srefDV)

        laplac += *(D_op,D_op)
    end
    RHS = spzeros(2*len, 2*len)
    
    for i in len+1:2*len
        for j in 1:len
            RHS[i,j] = laplac[i-len,j]
            RHS[j,j+len] = 1.0
        end
    end
    y0 = Array{Float64}([i<=len?f0coeffs[i]:v0coeffs[i-len] for i in 1:2*len])
    soln=ode78((t,x)->*(RHS,x), y0, [time0,time1])
    return soln
    
end