document.addEventListener('DOMContentLoaded', () => {
  // Toggle Password Show/Hide (Dapat bekerja di login.html & register.html)
  const passwordInput = document.getElementById('password') || document.getElementById('regPassword');
  const togglePasswordBtn = document.getElementById('togglePassword');
  const eyeIcon = document.getElementById('eyeIcon');

  if (togglePasswordBtn && passwordInput && eyeIcon) {
    togglePasswordBtn.addEventListener('click', () => {
      const isPassword = passwordInput.getAttribute('type') === 'password';
      passwordInput.setAttribute('type', isPassword ? 'text' : 'password');

      if (isPassword) {
        eyeIcon.classList.remove('fa-eye-slash');
        eyeIcon.classList.add('fa-eye');
      } else {
        eyeIcon.classList.remove('fa-eye');
        eyeIcon.classList.add('fa-eye-slash');
      }
    });
  }

  // Handling Form Login Submission
  const loginForm = document.getElementById('loginForm');
  if (loginForm) {
    loginForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const username = document.getElementById('username').value.trim();
      const password = document.getElementById('password').value.trim();

      if (!username || !password) {
        alert('Harap isi Username/Email dan Password terlebih dahulu!');
        return;
      }

      alert(`Login berhasil! Selamat datang kembali, ${username}.`);
    });
  }

  // Handling Form Register Submission
  const registerForm = document.getElementById('registerForm');
  if (registerForm) {
    registerForm.addEventListener('submit', (e) => {
      e.preventDefault();
      const fullname = document.getElementById('fullname').value.trim();
      const email = document.getElementById('regEmail').value.trim();
      const password = document.getElementById('regPassword').value.trim();

      if (!fullname || !email || !password) {
        alert('Harap isi seluruh data pendaftaran!');
        return;
      }

      alert(`Pendaftaran berhasil! Akun untuk ${fullname} telah dibuat. Silakan login.`);
      window.location.href = 'login.html';
    });
  }
});