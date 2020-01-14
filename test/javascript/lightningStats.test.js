import React from 'react';
import ReactDOM from 'react-dom';

import axios from 'axios';

import { mount, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import LightningStats from 'forkMonitorApp/components/lightningStats';

jest.mock('axios');

function flushPromises() {
  return new Promise(resolve => setImmediate(resolve));
}

const mockStats = {
  "penalty_count":2,
  "penalty_total": 1.33874639, // avoid 2 to keep test simple
  "sweep_count":3,
  "sweep_total": 0.383833
}

axios.get.mockImplementation(url => {
  if (url == "/api/v1/ln_stats.json") {
    return Promise.resolve({data: mockStats})
  } else {
      return Promise.reject({})
  }
});

describe('LightningStats', () => {
  let wrapper1, wrapper2;

  beforeAll(() => {
    wrapper1 = mount(<LightningStats penalties />);
    wrapper2 = mount(<LightningStats sweeps />);

  });

  test('should show penalty count', () => {
    expect(wrapper1.text()).toContain("2");
  });

  test('should show penalty total', () => {
    expect(wrapper1.text()).toContain("1.339");
  });

  test('should show sweep count', () => {
    expect(wrapper2.text()).toContain("3");
  });

  test('should show sweep total', () => {
    expect(wrapper2.text()).toContain("0.384");
  });

});
