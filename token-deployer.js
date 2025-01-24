document.addEventListener('DOMContentLoaded', function() {
    const form = document.getElementById('tokenForm');
    const websiteLinkInput = document.getElementById('websiteLink');
    const existingWebsiteRadio = document.getElementById('existingWebsite');
    const createWebsiteRadio = document.getElementById('createWebsite');

    // Handle website option changes
    function handleWebsiteOptionChange() {
        const webLinkInput = document.getElementById('webLinkInput');
        const websiteLinkInput = document.getElementById('websiteLink');
        
        if (existingWebsiteRadio.checked) {
            webLinkInput.classList.add('active');
            websiteLinkInput.required = true;
            websiteLinkInput.disabled = false;
        } else {
            webLinkInput.classList.remove('active');
            websiteLinkInput.required = false;
            websiteLinkInput.disabled = true;
            websiteLinkInput.value = '';
        }
        
        // Update progress after changing option
        updateProgress();
    }

    existingWebsiteRadio.addEventListener('change', handleWebsiteOptionChange);
    createWebsiteRadio.addEventListener('change', handleWebsiteOptionChange);

    // Handle form submission
    form.addEventListener('submit', async function(e) {
        e.preventDefault();

        // Get form data
        const formData = {
            tokenName: document.getElementById('tokenName').value,
            tokenTicker: document.getElementById('tokenTicker').value,
            tokenDescription: document.getElementById('tokenDescription').value,
            socialMedia: {
                twitter: document.getElementById('twitterLink').value,
                telegram: document.getElementById('telegramLink').value
            },
            websiteOption: document.querySelector('input[name="websiteOption"]:checked').value,
            websiteLink: document.getElementById('websiteLink').value
        };

        // Handle logo file
        const logoFile = document.getElementById('logoUpload').files[0];
        if (logoFile) {
            // Convert logo to base64 for API submission
            const reader = new FileReader();
            reader.readAsDataURL(logoFile);
            reader.onload = async function() {
                formData.logo = reader.result;
                await submitForm(formData);
            };
        } else {
            await submitForm(formData);
        }
    });

    async function submitForm(formData) {
        try {
            // Show loading state
            const submitButton = form.querySelector('button[type="submit"]');
            const originalButtonText = submitButton.textContent;
            submitButton.textContent = 'Creating Token...';
            submitButton.disabled = true;

            // Here you would typically send the data to your backend
            console.log('Form data to be submitted:', formData);
            
            // Simulate API call
            await new Promise(resolve => setTimeout(resolve, 2000));

            // Show success message
            alert('Token creation initiated successfully!');

            // Reset form
            form.reset();
            submitButton.textContent = originalButtonText;
            submitButton.disabled = false;

        } catch (error) {
            console.error('Error creating token:', error);
            alert('Error creating token. Please try again.');
            
            // Reset button state
            const submitButton = form.querySelector('button[type="submit"]');
            submitButton.textContent = 'Create Token';
            submitButton.disabled = false;
        }
    }

    // Initialize website option state
    handleWebsiteOptionChange();

    // Add inline validation
    function validateField(field) {
        const value = field.value.trim();
        const validationType = field.dataset.validation;
        const errorMessage = field.nextElementSibling;
        let isValid = true;

        if (validationType === 'required' && !value) {
            isValid = false;
        }

        if (field.type === 'url' && value && !isValidUrl(value)) {
            isValid = false;
        }

        if (field.id === 'tokenTicker' && value.length > 5) {
            isValid = false;
        }

        field.classList.toggle('error', !isValid);
        if (errorMessage && errorMessage.classList.contains('error-message')) {
            errorMessage.classList.toggle('visible', !isValid);
        }

        updateProgress();
        return isValid;
    }

    function isValidUrl(string) {
        try {
            new URL(string);
            return true;
        } catch (_) {
            return false;
        }
    }

    function updateProgress() {
        const totalFields = document.querySelectorAll('[data-validation]').length;
        const completedFields = Array.from(document.querySelectorAll('[data-validation]'))
            .filter(field => field.value.trim() !== '').length;
        
        const progress = (completedFields / totalFields) * 100;
        document.getElementById('progressBar').style.width = `${progress}%`;
    }

    // Add event listeners for inline validation
    document.querySelectorAll('.form-control').forEach(field => {
        field.addEventListener('blur', () => validateField(field));
        field.addEventListener('input', () => {
            if (field.classList.contains('error')) {
                validateField(field);
            }
            updateProgress();
        });
    });
}); 