# erase old function definitions to prevent issues
currdir = @__FILE__
pkgdir = currdir[1:end-13]

# Clean up directory status
run(`rm -rf $(pkgdir)deps/src/ $(pkgdir)deps/downloads/`)
run(`rm -rf $(pkgdir)src/Functions.jl`)
run(`touch $(pkgdir)src/Functions.jl`)
