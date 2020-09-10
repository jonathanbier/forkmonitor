import React from 'react';
import ReactDOM from 'react-dom';

import axios from 'axios';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import Lightning from 'forkMonitorApp/components/lightning';

jest.mock('axios');

function flushPromises() {
  return new Promise(resolve => setImmediate(resolve));
}

const mockPenalties = [
  {
    "id":2,
    "tx_id":"3e27208a91c1696fd63736f907dd26b55b68e1b2e8479d571974a0034b083808",
    "amount":"27387.0",
    "block":{"coin": "btc", "height":603483,"timestamp":1573576573,"id":160903,"hash":"0000000000000000000039464d9af0ba90e917e1d3f36eddef67ca54a2eb9cb4","work":91.3260366384208,"pool":"BTC.com","tx_count":2990,"size":1289642,"first_seen_by":{"id":19,"name_with_version":"Bitcoin Core 0.19.0.1"}}
  },
  {
    "id":1,
    "tx_id":"c64564a132778ba71ffb6188f7b92dac7c5d22afabeaec31f130bbd201ebb1b6",
    "amount":"3608648.0",
    "block":{"coin": "btc", "height":602649,"timestamp":1573082683,"id":161737,"hash":"00000000000000000008647bf3adffc88909838e32b9543d77086fb8dc6e40a5","work":91.3044362323286,"pool":"Poolin","tx_count":2563,"size":1075431,"first_seen_by":{"id":19,"name_with_version":"Bitcoin Core 0.19."}}
  }
]

axios.get.mockImplementation(url => {
  if (url == "/api/v1/ln_penalties.json") {
    return Promise.resolve({data: mockPenalties})
  } else {
      return Promise.reject({})
  }
});

test('rendered component', async () => {
  const wrapper = shallow(<Lightning match={{params: {}}} />);
  await flushPromises();
  expect(wrapper.find('Penalty')).toHaveLength(2);
});
