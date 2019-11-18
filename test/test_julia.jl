function test_nlpinterface(nlp::CUTEstModel, comp_nlp::AbstractNLPModel)
  x0 = nlp.meta.x0
  f(x) = obj(comp_nlp, x)
  g(x) = grad(comp_nlp, x)
  H(x; obj_weight=1.0) = tril(hess(comp_nlp, x, obj_weight=obj_weight),-1) +
                          hess(comp_nlp, x, obj_weight=obj_weight)'
  c(x) = cons(comp_nlp, x)
  J(x) = jac(comp_nlp, x)
  W(x, y; obj_weight=1.0) = tril(hess(comp_nlp, x, y, obj_weight=obj_weight),-1) +
                            hess(comp_nlp, x, y, obj_weight=obj_weight)'

  if nlp.meta.ncon > 0
    v = ones(nlp.meta.nvar)
    u = ones(nlp.meta.ncon)
  end

  rtol = 1e-8

  @testset "Julia interface" begin
    fx = obj(nlp, x0)
    @test isapprox(fx, f(x0), rtol=rtol)

    (fx, gx) = objgrad(nlp, x0)
    @test isapprox(fx, f(x0), rtol=rtol)
    @test isapprox(gx, g(x0), rtol=rtol)

    gx = grad(nlp, x0)
    @test isapprox(gx, g(x0), rtol=rtol)

    fill!(gx, 0.0)
    grad!(nlp, x0, gx)
    @test isapprox(gx, g(x0), rtol=rtol)

    if nlp.meta.ncon > 0
      (fx, cx) = objcons(nlp, x0)
      @test isapprox(fx, f(x0), rtol=rtol)
      @test isapprox(cx, c(x0), rtol=rtol)

      (cx, jrow, jcol, jval) = cons_coord(nlp, x0)
      Jx = sparse(jrow, jcol, jval, nlp.meta.ncon, nlp.meta.nvar)
      @test isapprox(cx, c(x0), rtol=rtol)
      @test isapprox(Jx, J(x0), rtol=rtol)

      (cx, Jx) = consjac(nlp, x0)
      @test isapprox(cx, c(x0), rtol=rtol)
      @test isapprox(Jx, J(x0), rtol=rtol)

      cx = cons(nlp, x0) # This is here to improve coverage
      @test isapprox(cx, c(x0), rtol=rtol)

      fill!(cx, 0.0)
      cons!(nlp, x0, cx)
      @test isapprox(cx, c(x0), rtol=rtol)

      jval = jac_coord(nlp, x0)
      Jx = sparse(jrow, jcol, jval, nlp.meta.ncon, nlp.meta.nvar)
      @test isapprox(Jx, J(x0), rtol=rtol)

      Jx = jac(nlp, x0)
      @test isapprox(Jx, J(x0), rtol=rtol)

      Jv = jprod(nlp, x0, v)
      @test isapprox(Jv, J(x0)*v, rtol=rtol)

      Jtu = jtprod(nlp, x0, u)
      @test isapprox(Jtu, J(x0)'*u, rtol=rtol)
    end

    v = rand(nlp.meta.nvar)
    obj_weights = [0.0, 1.0, 3.141592]
    for obj_weight in obj_weights
      Hx = hess(nlp, x0, obj_weight=obj_weight)
      @test isapprox(Hx, tril(H(x0, obj_weight=obj_weight)), rtol=rtol)
      if nlp.meta.ncon > 0
        Wx = hess(nlp, x0, ones(nlp.meta.ncon), obj_weight=obj_weight)
        @test isapprox(Wx, tril(W(x0, ones(nlp.meta.ncon),
                                  obj_weight=obj_weight)), rtol=rtol)
      end

      hv = hprod(nlp, x0, v, obj_weight=obj_weight)
      @test isapprox(hv, H(x0, obj_weight=obj_weight)*v, rtol=rtol)

      fill!(hv, 0.0)
      hprod!(nlp, x0, v, hv, obj_weight=obj_weight)
      @test isapprox(hv, H(x0, obj_weight=obj_weight)*v, rtol=rtol)

      if nlp.meta.ncon > 0
        hv = hprod(nlp, x0, ones(nlp.meta.ncon), v, obj_weight=obj_weight)
        @test isapprox(hv, W(x0, ones(nlp.meta.ncon),
                             obj_weight=obj_weight)*v, rtol=rtol)

        fill!(hv, 0.0)
        hprod!(nlp, x0, ones(nlp.meta.ncon), v, hv, obj_weight=obj_weight)
        @test isapprox(hv, W(x0, ones(nlp.meta.ncon),
                             obj_weight=obj_weight)*v, rtol=rtol)
      end
    end

    if nlp.meta.ncon > 0
      @assert nlp.counters.neval_obj == 3
      @assert nlp.counters.neval_grad == 3
      @assert nlp.counters.neval_cons == 5
      @assert nlp.counters.neval_jac == 4
      @assert nlp.counters.neval_jprod == 1
      @assert nlp.counters.neval_jtprod == 1
      @assert nlp.counters.neval_hess == 2 * length(obj_weights)
      @assert nlp.counters.neval_hprod == 4 * length(obj_weights)
    else
      @assert nlp.counters.neval_obj == 2
      @assert nlp.counters.neval_grad == 3
      @assert nlp.counters.neval_cons == 0
      @assert nlp.counters.neval_jac == 0
      @assert nlp.counters.neval_jprod == 0
      @assert nlp.counters.neval_jtprod == 0
      @assert nlp.counters.neval_hess == 1 * length(obj_weights)
      @assert nlp.counters.neval_hprod == 2 * length(obj_weights)
    end

    print("Julia interface stress test... ")
    for i = 1:10000
      fx = obj(nlp, x0)
      (fx, gx) = objgrad(nlp, x0)
      gx = grad(nlp, x0)
      grad!(nlp, x0, gx)
      Hx = hess(nlp, x0)
      v = rand(nlp.meta.nvar)
      hv = hprod(nlp, x0, v)
      hprod!(nlp, x0, v, hv)
      if nlp.meta.ncon > 0
        (fx, cx) = objcons(nlp, x0)
        (cx, jrow, jcol, jval) = cons_coord(nlp, x0)
        Jx = sparse(jrow, jcol, jval, nlp.meta.ncon, nlp.meta.nvar)
        (cx, Jx) = consjac(nlp, x0)
        cx = cons(nlp, x0)
        cons!(nlp, x0, cx)
        jval = jac_coord(nlp, x0)
        Jx = sparse(jrow, jcol, jval, nlp.meta.ncon, nlp.meta.nvar)
        Jx = jac(nlp, x0)
        jv = jprod(nlp, x0, v)
        jtu = jtprod(nlp, x0, u)
        Wx = hess(nlp, x0, ones(nlp.meta.ncon))
        hv = hprod(nlp, x0, ones(nlp.meta.ncon), v)
        hprod!(nlp, x0, ones(nlp.meta.ncon), v, hv)
      end
    end
    println("Passed")
  end
end
