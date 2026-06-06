;;; Crate sources for rust-sysroot-riscv32imac-xous-elf dependencies
;;;
;;; This file is managed by 'guix import'.  Do NOT add definitions manually.
;;; Regenerate from betrusted-io/rust's library/Cargo.lock with:
;;;   guix import -i packages/xous-sysroot-crates.scm \
;;;       crate --lockfile=../rust/library/Cargo.lock sysroot

(define-module (xous-sysroot-crates)
  #:use-module (guix build-system cargo)
  #:export (lookup-cargo-inputs))

(define qqqq-separator 'begin-of-crates)

(define rust-addr2line-0.25.1
  (crate-source "addr2line" "0.25.1"
                "0jwb96gv17vdr29hbzi0ha5q6jkpgjyn7rjlg5nis65k41rk0p8v"))

(define rust-adler2-2.0.1
  (crate-source "adler2" "2.0.1"
                "1ymy18s9hs7ya1pjc9864l30wk8p2qfqdi7mhhcc5nfakxbij09j"))

(define rust-cc-1.2.0
  (crate-source "cc" "1.2.0"
                "1f3dndil5f864zhyc6f513xshs6b8mlxn0ipqww0awdxb0hr7sqs"))

(define rust-cfg-if-1.0.4
  (crate-source "cfg-if" "1.0.4"
                "008q28ajc546z5p2hcwdnckmg0hia7rnx52fni04bwqkzyrghc4k"))

(define rust-dlmalloc-0.2.11
  (crate-source "dlmalloc" "0.2.11"
                "0c7sygw9dlczgjkk6kvp2sxrz81zc51rgrycah69kp8n1csgxk86"))

(define rust-foldhash-0.2.0
  (crate-source "foldhash" "0.2.0"
                "1nvgylb099s11xpfm1kn2wcsql080nqmnhj1l25bp3r2b35j9kkp"))

(define rust-fortanix-sgx-abi-0.6.1
  (crate-source "fortanix-sgx-abi" "0.6.1"
                "113gvr6azrpcixbbinl7scyzdpsrd3dd079pyja86gmqspnqbz2y"))

(define rust-getopts-0.2.24
  (crate-source "getopts" "0.2.24"
                "1pylvsmq7fillnxmd6g58r7igdrlby412q37ws41z39va2ngpr6g"))

(define rust-gimli-0.32.3
  (crate-source "gimli" "0.32.3"
                "1iqk5xznimn5bfa8jy4h7pa1dv3c624hzgd2dkz8mpgkiswvjag6"))

(define rust-hashbrown-0.16.1
  (crate-source "hashbrown" "0.16.1"
                "004i3njw38ji3bzdp9z178ba9x3k0c1pgy8x69pj7yfppv4iq7c4"))

(define rust-hermit-abi-0.5.2
  (crate-source "hermit-abi" "0.5.2"
                "1744vaqkczpwncfy960j2hxrbjl1q01csm84jpd9dajbdr2yy3zw"))

(define rust-libc-0.2.177
  (crate-source "libc" "0.2.177"
                "0xjrn69cywaii1iq2lib201bhlvan7czmrm604h5qcm28yps4x18"))

(define rust-memchr-2.7.6
  (crate-source "memchr" "2.7.6"
                "0wy29kf6pb4fbhfksjbs05jy2f32r2f3r1ga6qkmpz31k79h0azm"))

(define rust-miniz-oxide-0.8.9
  (crate-source "miniz_oxide" "0.8.9"
                "05k3pdg8bjjzayq3rf0qhpirq9k37pxnasfn4arbs17phqn6m9qz"))

(define rust-moto-rt-0.15.2
  (crate-source "moto-rt" "0.15.2"
                "0cfhr15wz7iim0fwci71g14vj2d9rj0ck7n0jb5h4d9vglwbrx0b"))

(define rust-object-0.37.3
  (crate-source "object" "0.37.3"
                "1zikiy9xhk6lfx1dn2gn2pxbnfpmlkn0byd7ib1n720x0cgj0xpz"))

(define rust-r-efi-5.3.0
  (crate-source "r-efi" "5.3.0"
                "03sbfm3g7myvzyylff6qaxk4z6fy76yv860yy66jiswc2m6b7kb9"))

(define rust-r-efi-alloc-2.1.0
  (crate-source "r-efi-alloc" "2.1.0"
                "0m338vaggbcc2x04lcf99kwkvk8vc0vqbanr8jf0zfx97kpmhbyw"))

(define rust-rand-0.9.2
  (crate-source "rand" "0.9.2"
                "1lah73ainvrgl7brcxx0pwhpnqa3sm3qaj672034jz8i0q7pgckd"))

(define rust-rand-core-0.9.3
  (crate-source "rand_core" "0.9.3"
                "0f3xhf16yks5ic6kmgxcpv1ngdhp48mmfy4ag82i1wnwh8ws3ncr"))

(define rust-rand-xorshift-0.4.0
  (crate-source "rand_xorshift" "0.4.0"
                "0njsn25pis742gb6b89cpq7jp48v9n23a9fvks10yczwks8n4fai"))

(define rust-rustc-demangle-0.1.26
  (crate-source "rustc-demangle" "0.1.26"
                "1kja3nb0yhlm4j2p1hl8d7sjmn2g9fa1s4pj0qma5kj2lcndkxsn"))

(define rust-rustc-literal-escaper-0.0.5
  (crate-source "rustc-literal-escaper" "0.0.5"
                "12s3w2mpgpjgzi6w19k6yr6vfcczkd6cv4vld514z9f5fzd2kvp4"))

(define rust-shlex-1.3.0
  (crate-source "shlex" "1.3.0"
                "0r1y6bv26c1scpxvhg2cabimrmwgbp4p3wy6syj9n0c4s3q2znhg"))

(define rust-unwinding-0.2.8
  (crate-source "unwinding" "0.2.8"
                "0vdx3c8183gz5rkxl5bxiflc0hi94lgkkif8kprrj5plbs22qqb0"))

(define rust-vex-sdk-0.27.1
  (crate-source "vex-sdk" "0.27.1"
                "1xlv6wilgynvrx4wyd458a2z8ngzgxqwpqimid3ha4yymwazxrbr"))

(define rust-wasi-0.11.1+wasi-snapshot-preview1
  (crate-source "wasi" "0.11.1+wasi-snapshot-preview1"
                "0jx49r7nbkbhyfrfyhz0bm4817yrnxgd3jiwwwfv0zl439jyrwyc"))

(define rust-wasi-0.14.4+wasi-0.2.4
  (crate-source "wasi" "0.14.4+wasi-0.2.4"
                "0jpcy0qg3bvsclwyk1d11r3isd320rpickrl5hy9rx7s4jjg99c8"))

(define rust-windows-link-0.2.1
  (crate-source "windows-link" "0.2.1"
                "1rag186yfr3xx7piv5rg8b6im2dwcf8zldiflvb22xbzwli5507h"))

(define rust-windows-sys-0.60.2
  (crate-source "windows-sys" "0.60.2"
                "1jrbc615ihqnhjhxplr2kw7rasrskv9wj3lr80hgfd42sbj01xgj"))

(define rust-windows-targets-0.53.5
  (crate-source "windows-targets" "0.53.5"
                "1wv9j2gv3l6wj3gkw5j1kr6ymb5q6dfc42yvydjhv3mqa7szjia9"))

(define rust-windows-aarch64-gnullvm-0.53.1
  (crate-source "windows_aarch64_gnullvm" "0.53.1"
                "0lqvdm510mka9w26vmga7hbkmrw9glzc90l4gya5qbxlm1pl3n59"))

(define rust-windows-aarch64-msvc-0.53.1
  (crate-source "windows_aarch64_msvc" "0.53.1"
                "01jh2adlwx043rji888b22whx4bm8alrk3khjpik5xn20kl85mxr"))

(define rust-windows-i686-gnu-0.53.1
  (crate-source "windows_i686_gnu" "0.53.1"
                "18wkcm82ldyg4figcsidzwbg1pqd49jpm98crfz0j7nqd6h6s3ln"))

(define rust-windows-i686-gnullvm-0.53.1
  (crate-source "windows_i686_gnullvm" "0.53.1"
                "030qaxqc4salz6l4immfb6sykc6gmhyir9wzn2w8mxj8038mjwzs"))

(define rust-windows-i686-msvc-0.53.1
  (crate-source "windows_i686_msvc" "0.53.1"
                "1hi6scw3mn2pbdl30ji5i4y8vvspb9b66l98kkz350pig58wfyhy"))

(define rust-windows-x86-64-gnu-0.53.1
  (crate-source "windows_x86_64_gnu" "0.53.1"
                "16d4yiysmfdlsrghndr97y57gh3kljkwhfdbcs05m1jasz6l4f4w"))

(define rust-windows-x86-64-gnullvm-0.53.1
  (crate-source "windows_x86_64_gnullvm" "0.53.1"
                "1qbspgv4g3q0vygkg8rnql5c6z3caqv38japiynyivh75ng1gyhg"))

(define rust-windows-x86-64-msvc-0.53.1
  (crate-source "windows_x86_64_msvc" "0.53.1"
                "0l6npq76vlq4ksn4bwsncpr8508mk0gmznm6wnhjg95d19gzzfyn"))

(define rust-wit-bindgen-0.45.1
  (crate-source "wit-bindgen" "0.45.1"
                "0dndrimz95nwdv6m24ylj0vj1dvlc012xxrxs13mc1r5y5qk8msw"))

(define ssss-separator 'end-of-crates)


;;;
;;; Cargo inputs.
;;;

(define-cargo-inputs lookup-cargo-inputs
                     (sysroot =>
                              (list rust-addr2line-0.25.1
                                    rust-adler2-2.0.1
                                    rust-cc-1.2.0
                                    rust-cfg-if-1.0.4
                                    rust-dlmalloc-0.2.11
                                    rust-foldhash-0.2.0
                                    rust-fortanix-sgx-abi-0.6.1
                                    rust-getopts-0.2.24
                                    rust-gimli-0.32.3
                                    rust-hashbrown-0.16.1
                                    rust-hermit-abi-0.5.2
                                    rust-libc-0.2.177
                                    rust-memchr-2.7.6
                                    rust-miniz-oxide-0.8.9
                                    rust-moto-rt-0.15.2
                                    rust-object-0.37.3
                                    rust-r-efi-5.3.0
                                    rust-r-efi-alloc-2.1.0
                                    rust-rand-0.9.2
                                    rust-rand-core-0.9.3
                                    rust-rand-xorshift-0.4.0
                                    rust-rustc-demangle-0.1.26
                                    rust-rustc-literal-escaper-0.0.5
                                    rust-shlex-1.3.0
                                    rust-unwinding-0.2.8
                                    rust-vex-sdk-0.27.1
                                    rust-wasi-0.11.1+wasi-snapshot-preview1
                                    rust-wasi-0.14.4+wasi-0.2.4
                                    rust-windows-link-0.2.1
                                    rust-windows-sys-0.60.2
                                    rust-windows-targets-0.53.5
                                    rust-windows-aarch64-gnullvm-0.53.1
                                    rust-windows-aarch64-msvc-0.53.1
                                    rust-windows-i686-gnu-0.53.1
                                    rust-windows-i686-gnullvm-0.53.1
                                    rust-windows-i686-msvc-0.53.1
                                    rust-windows-x86-64-gnu-0.53.1
                                    rust-windows-x86-64-gnullvm-0.53.1
                                    rust-windows-x86-64-msvc-0.53.1
                                    rust-wit-bindgen-0.45.1)))
