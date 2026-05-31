const HomePage = {
  mounted() {
    this.initScrollProgress()
    this.initNav()
    this.initReveal()
    this.initCounters()
    this.initTyping()
    this.initTestimonials()
    this.initCursorGlow()
    this.initMobileMenu()
    this.initParticles()
    this.initThemeToggle()
    this.initSmoothScroll()
    this.initCategoryTilt()
    this.initParallax()
    this.initActiveNav()
    this.initMagneticButtons()
    this.initStaggerReveal()
  },

  destroyed() {
    if (this._parallaxHandler) window.removeEventListener("scroll", this._parallaxHandler)
    if (this._progressHandler) window.removeEventListener("scroll", this._progressHandler)
    if (this._navHandler) window.removeEventListener("scroll", this._navHandler)
  },

  initScrollProgress() {
    const bar = this.el.querySelector("[data-scroll-progress]")
    if (!bar) return
    this._progressHandler = () => {
      const h = document.documentElement.scrollHeight - window.innerHeight
      const p = h > 0 ? (window.scrollY / h) * 100 : 0
      bar.style.width = `${p}%`
    }
    window.addEventListener("scroll", this._progressHandler, {passive: true})
    this._progressHandler()
  },

  initThemeToggle() {
    const btn = document.getElementById("home-theme-toggle")
    if (!btn) return
    btn.addEventListener("click", () => {
      const next = document.documentElement.getAttribute("data-theme") === "dark" ? "light" : "dark"
      localStorage.setItem("phx:theme", next)
      document.documentElement.setAttribute("data-theme", next)
    })
  },

  initNav() {
    const nav = document.getElementById("home-nav")
    if (!nav) return
    const onScroll = () => nav.classList.toggle("scrolled", window.scrollY > 20)
    onScroll()
    window.addEventListener("scroll", onScroll, {passive: true})
  },

  initActiveNav() {
    const links = this.el.querySelectorAll("[data-nav-section]")
    const sections = [...links].map(l => document.querySelector(l.getAttribute("href"))).filter(Boolean)
    if (!sections.length) return

    this._navHandler = () => {
      const y = window.scrollY + 120
      let current = sections[0]
      sections.forEach(sec => {
        if (sec.offsetTop <= y) current = sec
      })
      links.forEach(link => {
        const active = link.getAttribute("href") === `#${current.id}`
        link.classList.toggle("nav-link-active", active)
      })
    }
    window.addEventListener("scroll", this._navHandler, {passive: true})
    this._navHandler()
  },

  initSmoothScroll() {
    this.el.querySelectorAll('a[href^="#"]').forEach(a => {
      a.addEventListener("click", e => {
        const id = a.getAttribute("href")
        if (id.length < 2) return
        const el = document.querySelector(id)
        if (!el) return
        e.preventDefault()
        el.scrollIntoView({behavior: "smooth", block: "start"})
        document.getElementById("home-mobile-menu")?.classList.remove("open")
        document.getElementById("home-menu-overlay")?.classList.add("hidden")
        document.body.style.overflow = ""
      })
    })
  },

  initParallax() {
    const blobs = this.el.querySelectorAll(".sb-blob")
    if (!blobs.length || window.matchMedia("(max-width: 1024px)").matches) return

    this._parallaxHandler = () => {
      const y = window.scrollY * 0.15
      blobs.forEach((b, i) => {
        b.style.transform = `translateY(${y * (i % 2 === 0 ? 1 : -0.6)}px)`
      })
    }
    window.addEventListener("scroll", this._parallaxHandler, {passive: true})
  },

  initCategoryTilt() {
    if (window.matchMedia("(max-width: 768px)").matches) return

    this.el.querySelectorAll(".sb-category-card").forEach(card => {
      card.addEventListener("mousemove", e => {
        const rect = card.getBoundingClientRect()
        const x = (e.clientX - rect.left) / rect.width - 0.5
        const y = (e.clientY - rect.top) / rect.height - 0.5
        card.style.transform = `perspective(600px) rotateY(${x * 10}deg) rotateX(${-y * 10}deg) translateY(-8px)`
      })
      card.addEventListener("mouseleave", () => {
        card.style.transform = ""
      })
    })
  },

  initReveal() {
    const els = this.el.querySelectorAll(".sb-reveal")
    if (!els.length) return
    const io = new IntersectionObserver(
      entries => {
        entries.forEach(e => {
          if (e.isIntersecting) {
            e.target.classList.add("sb-visible")
            io.unobserve(e.target)
          }
        })
      },
      {threshold: 0.08, rootMargin: "0px 0px -60px 0px"}
    )
    els.forEach(el => io.observe(el))
  },

  initCounters() {
    const section = this.el.querySelector("[data-counters]")
    if (!section) return
    let done = false
    const run = () => {
      if (done) return
      done = true
      section.querySelectorAll("[data-count]").forEach(el => {
        const target = parseInt(el.dataset.count, 10)
        const suffix = el.dataset.suffix || ""
        const duration = 2000
        const start = performance.now()
        const tick = now => {
          const p = Math.min((now - start) / duration, 1)
          const eased = 1 - Math.pow(1 - p, 4)
          el.textContent = Math.floor(target * eased).toLocaleString() + suffix
          if (p < 1) requestAnimationFrame(tick)
        }
        requestAnimationFrame(tick)
      })
    }
    const io = new IntersectionObserver(
      entries => {
        if (entries.some(e => e.isIntersecting)) {
          run()
          io.disconnect()
        }
      },
      {threshold: 0.25}
    )
    io.observe(section)
  },

  initTyping() {
    const el = this.el.querySelector("[data-typing]")
    if (!el) return
    const phrases = JSON.parse(el.dataset.phrases || "[]")
    if (!phrases.length) return
    let pi = 0
    let ci = 0
    let deleting = false
    const type = () => {
      const phrase = phrases[pi]
      el.textContent = phrase.slice(0, ci)
      if (!deleting && ci < phrase.length) {
        ci++
        setTimeout(type, 48)
      } else if (!deleting && ci === phrase.length) {
        deleting = true
        setTimeout(type, 2400)
      } else if (deleting && ci > 0) {
        ci--
        setTimeout(type, 30)
      } else {
        deleting = false
        pi = (pi + 1) % phrases.length
        setTimeout(type, 350)
      }
    }
    el.classList.add("sb-typing-cursor")
    type()
  },

  initTestimonials() {
    const track = this.el.querySelector("[data-testimonial-track]")
    const dots = this.el.querySelectorAll("[data-testimonial-dot]")
    if (!track || !dots.length) return
    let i = 0
    const slides = track.children.length
    const go = idx => {
      i = idx
      track.style.transform = `translateX(-${idx * 100}%)`
      dots.forEach((d, j) => {
        d.classList.toggle("sb-dot-active", j === idx)
        d.classList.toggle("bg-slate-300", j !== idx)
        d.classList.toggle("w-2.5", j !== idx)
        d.classList.toggle("w-2", j !== idx)
      })
    }
    dots.forEach((d, j) => d.addEventListener("click", () => go(j)))
    const startAuto = () => {
      this._testimonialInterval = setInterval(() => go((i + 1) % slides), 6000)
    }
    startAuto()
    const parent = track.parentElement
    parent?.addEventListener("mouseenter", () => clearInterval(this._testimonialInterval))
    parent?.addEventListener("mouseleave", startAuto)
  },

  initMagneticButtons() {
    if (window.matchMedia("(max-width: 768px)").matches) return
    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return

    this.el.querySelectorAll(".sb-btn-primary, .sb-nav-cta").forEach(btn => {
      btn.classList.add("sb-magnetic")
      btn.addEventListener("mousemove", e => {
        const rect = btn.getBoundingClientRect()
        const x = (e.clientX - rect.left - rect.width / 2) * 0.12
        const y = (e.clientY - rect.top - rect.height / 2) * 0.12
        btn.style.transform = `translate(${x}px, ${y}px) translateY(-3px)`
      })
      btn.addEventListener("mouseleave", () => {
        btn.style.transform = ""
      })
    })
  },

  initStaggerReveal() {
    const parent = this.el.querySelector(".sb-stagger-parent")
    if (!parent) return

    const io = new IntersectionObserver(
      entries => {
        entries.forEach(e => {
          if (e.isIntersecting) {
            e.target.classList.add("sb-visible")
            io.unobserve(e.target)
          }
        })
      },
      {threshold: 0.1}
    )
    io.observe(parent)
  },

  initCursorGlow() {
    const glow = this.el.querySelector("[data-cursor-glow]")
    if (!glow || window.matchMedia("(max-width: 768px)").matches) return
    window.addEventListener(
      "mousemove",
      e => {
        glow.style.left = `${e.clientX}px`
        glow.style.top = `${e.clientY}px`
        glow.style.opacity = "1"
      },
      {passive: true}
    )
  },

  initMobileMenu() {
    const menu = document.getElementById("home-mobile-menu")
    const openBtn = document.getElementById("home-menu-open")
    const closeBtn = document.getElementById("home-menu-close")
    const overlay = document.getElementById("home-menu-overlay")
    if (!menu) return
    const open = () => {
      menu.classList.add("open")
      overlay?.classList.remove("hidden")
      document.body.style.overflow = "hidden"
    }
    const close = () => {
      menu.classList.remove("open")
      overlay?.classList.add("hidden")
      document.body.style.overflow = ""
    }
    openBtn?.addEventListener("click", open)
    closeBtn?.addEventListener("click", close)
    overlay?.addEventListener("click", close)
  },

  initParticles() {
    const wrap = this.el.querySelector("[data-particles]")
    if (!wrap) return
    for (let i = 0; i < 40; i++) {
      const p = document.createElement("span")
      p.className = "sb-particle"
      const size = 2 + Math.random() * 4
      p.style.width = `${size}px`
      p.style.height = `${size}px`
      p.style.left = `${Math.random() * 100}%`
      p.style.animationDelay = `${Math.random() * 14}s`
      p.style.animationDuration = `${8 + Math.random() * 10}s`
      wrap.appendChild(p)
    }
  }
}

export default {HomePage: HomePage}
