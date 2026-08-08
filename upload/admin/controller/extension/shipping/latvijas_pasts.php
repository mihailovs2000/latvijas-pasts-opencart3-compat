<?php
class ControllerExtensionShippingLatvijasPasts extends Controller {
	private $error = array();

	public function index() {
		$this->load->language('extension/shipping/latvijas_pasts');
		$this->document->setTitle($this->language->get('heading_title'));
		$this->load->model('setting/setting');

		if ($this->request->server['REQUEST_METHOD'] === 'POST' && $this->validate()) {
			$this->model_setting_setting->editSetting('shipping_latvijas_pasts', $this->request->post);
			$this->session->data['success'] = $this->language->get('text_success');
			$this->response->redirect($this->url->link('marketplace/extension', 'user_token=' . $this->session->data['user_token'] . '&type=shipping', true));
		}

		$data['error_warning'] = isset($this->error['warning']) ? $this->error['warning'] : '';
		$data['error_cost'] = isset($this->error['cost']) ? $this->error['cost'] : '';
		$data['error_free_total'] = isset($this->error['free_total']) ? $this->error['free_total'] : '';
		$data['error_cache_ttl'] = isset($this->error['cache_ttl']) ? $this->error['cache_ttl'] : '';

		$data['breadcrumbs'] = array(
			array('text' => $this->language->get('text_home'), 'href' => $this->url->link('common/dashboard', 'user_token=' . $this->session->data['user_token'], true)),
			array('text' => $this->language->get('text_extension'), 'href' => $this->url->link('marketplace/extension', 'user_token=' . $this->session->data['user_token'] . '&type=shipping', true)),
			array('text' => $this->language->get('heading_title'), 'href' => $this->url->link('extension/shipping/latvijas_pasts', 'user_token=' . $this->session->data['user_token'], true))
		);

		$data['action'] = $this->url->link('extension/shipping/latvijas_pasts', 'user_token=' . $this->session->data['user_token'], true);
		$data['cancel'] = $this->url->link('marketplace/extension', 'user_token=' . $this->session->data['user_token'] . '&type=shipping', true);

		$defaults = array(
			'shipping_latvijas_pasts_cost' => '5.00',
			'shipping_latvijas_pasts_free_total' => '0',
			'shipping_latvijas_pasts_tax_class_id' => '0',
			'shipping_latvijas_pasts_geo_zone_id' => '0',
			'shipping_latvijas_pasts_cache_ttl' => '86400',
			'shipping_latvijas_pasts_sort_order' => '0',
			'shipping_latvijas_pasts_status' => '0'
		);

		foreach ($defaults as $key => $default) {
			if (isset($this->request->post[$key])) {
				$data[$key] = $this->request->post[$key];
			} elseif ($this->config->has($key)) {
				$data[$key] = $this->config->get($key);
			} else {
				$data[$key] = $default;
			}
		}

		$this->load->model('localisation/tax_class');
		$data['tax_classes'] = $this->model_localisation_tax_class->getTaxClasses();
		$this->load->model('localisation/geo_zone');
		$data['geo_zones'] = $this->model_localisation_geo_zone->getGeoZones();

		$data['header'] = $this->load->controller('common/header');
		$data['column_left'] = $this->load->controller('common/column_left');
		$data['footer'] = $this->load->controller('common/footer');
		$this->response->setOutput($this->load->view('extension/shipping/latvijas_pasts', $data));
	}

	protected function validate() {
		if (!$this->user->hasPermission('modify', 'extension/shipping/latvijas_pasts')) {
			$this->error['warning'] = $this->language->get('error_permission');
		}

		$cost = isset($this->request->post['shipping_latvijas_pasts_cost']) ? str_replace(',', '.', trim($this->request->post['shipping_latvijas_pasts_cost'])) : '';
		if ($cost === '' || !is_numeric($cost) || (float)$cost < 0) {
			$this->error['cost'] = $this->language->get('error_cost');
		}

		$free_total = isset($this->request->post['shipping_latvijas_pasts_free_total']) ? str_replace(',', '.', trim($this->request->post['shipping_latvijas_pasts_free_total'])) : '';
		if ($free_total !== '' && (!is_numeric($free_total) || (float)$free_total < 0)) {
			$this->error['free_total'] = $this->language->get('error_free_total');
		}

		$cache_ttl = isset($this->request->post['shipping_latvijas_pasts_cache_ttl']) ? trim($this->request->post['shipping_latvijas_pasts_cache_ttl']) : '';
		if (!ctype_digit($cache_ttl) || (int)$cache_ttl < 300 || (int)$cache_ttl > 604800) {
			$this->error['cache_ttl'] = $this->language->get('error_cache_ttl');
		}

		return !$this->error;
	}
}
